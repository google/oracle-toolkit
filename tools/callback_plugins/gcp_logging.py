"""Ansible callback plugin that pushes playbook events to Google Cloud Logging."""

from __future__ import annotations  # required for annotations in TypeDicts

import atexit
import datetime
import getpass
import os
import queue
import sys
import threading
from typing import Any, Dict, Optional, TypedDict
import uuid

import ansible
from ansible import context
# When Ansible runs, it dynamically and automatically constructs a namespace
# (ansible_collections) and merges Ansible-provided and user-provided
# module utilities to the dynamically-constructed namespace. See
# https://docs.ansible.com/ansible/latest/dev_guide/developing_module_utilities.html#using-and-developing-module-utilities.
from ansible.module_utils.parsing import convert_bool
from ansible.plugins import callback
from ansible_collections.google.cloud.plugins.module_utils.gcp_utils import GcpSession


DOCUMENTATION = """
  name: cloud_full_logging
  type: aggregate
  options:
    project:
      description: Project ID of the Google Cloud project to which logs are sent
      required: true
      type: str
      env:
        - name: ANSIBLE_CLOUD_LOGGING_PROJECT
      ini:
        - section: cloud_logging
          key: project
    log_name:
      description: LOG_ID of the log entry name.
      type: str
      default: ansible_cloud_logging
      env:
        - name: ANSIBLE_CLOUD_LOGGING_LOG_NAME
      ini:
        - section: cloud_logging
          key: log_name
    ignore_errors:
      description: If enabled (default) GCP API errors are ignored and Ansible will not exit early.
      type: bool
      default: True
      env:
        - name: ANSIBLE_CLOUD_LOGGING_IGNORE_ERRORS
      ini:
        - section: cloud_logging
          key: ignore_errors
    print_uuid:
      description: If enabled, print the UUID of the Playbook execution.
      type: bool
      default: False
      env:
        - name: ANSIBLE_CLOUD_LOGGING_PRINT_UUID
      ini:
        - section: cloud_logging
          key: print_uuid
    multiprocessing:
      description: If enabled, use multiprocessing to send logs to GCP. This speeds up Ansible execution significantly.
      type: bool
      default: False
      env:
        - name: ANSIBLE_CLOUD_LOGGING_MULTIPROCESSING
      ini:
        - section: cloud_logging
          key: multiprocessing
"""


def _print_uuid(execution_id: str) -> None:
  """Prints the UUID of the logging entry.

  Args:
    execution_id: The UUUID of the logging entry.
  """
  print(f"\nPlaybook execution UUID: {execution_id}\n")


class PlaybookStartMessage(TypedDict):
  """Defines the serializable message for a playbook start event.

  params:
    id: Unique ID of the playbook execution.
    event_type: Type of the event.
    user: Username of the user executing the playbook.
    start_time: Timestamp when the playbook execution started.
    playbook_name: Name of the playbook file.
    playbook_basedir: Base directory of the playbook.
    inventories: List of inventories used for the playbook execution.
    extra_vars: Extra variables passed to the playbook.
    check: Flag to indicate if the playbook runs in dry-mode.
    limit: Subset of hosts to be used for the playbook execution.
    env: Environment variables set for the playbook execution.
  """

  id: str
  event_type: str
  user: str
  start_time: str
  playbook_name: str
  playbook_basedir: str
  inventories: list[str]
  extra_vars: dict[str, str]
  check: bool
  limit: str
  env: dict[str, str]


class PlaybookTaskEndMessage(TypedDict):
  """Defines the serializable message for a playbook task event.

  params:
    id: Unique ID of the playbook execution.
    event_type: Type of the event.
    task_id: Unique ID of the task.
    name: Name of the task.
    host: Hostname of the host where the task is executed.
    start_time: Timestamp when the task execution started.
    end_time: Timestamp when the task execution ended.
    status: Status of the task (OK, FAILED, SKIPPED, etc.)
    result: Dictionary containing the execution result.
  """

  id: str
  event_type: str
  task_id: str
  name: str
  host: str
  start_time: str
  end_time: str
  status: str
  result: dict[str, Any]


class PlaybookTaskStartMessage(TypedDict):
  """Defines the serializable message for a playbook task start event.

  params:
    id: Unique ID of the playbook execution.
    event_type: Type of the event.
    task_id: Unique ID of the task.
    name: Name of the task.
    host: Hostname of the host where the task is executed.
    start_time: Timestamp when the task execution started.
    end_time: Timestamp when the task execution ended.
    status: Status of the task (OK, FAILED, SKIPPED, etc.)
    result: Dictionary containing the execution result.
  """

  id: str
  event_type: str
  task_id: str
  name: str
  host: str
  start_time: str


class PlaybookEndMessage(TypedDict):
  """Defines the serializable message for a playbook end event.

  params:
    id: Unique ID of the playbook execution.
    event_type: Type of the event.
    user: Username of the user executing the playbook.
    start_time: Timestamp when the playbook execution started.
    end_time: Timestamp when the playbook execution ended.
    stats: Dictionary containing summary statistics.
  """

  id: str
  event_type: str
  user: str
  start_time: str
  end_time: str
  stats: dict[str, Any]


class CloudLoggingCollector:
  """Provides a thread for collecting and sending logs to GCP Logging.

  Create a new CloudLoggingCollector instance by passing the project and
  the log_name. New messages can be added to the queue via calling
  CloudLoggingCollector.send(msg). The separate worker thread running in the
  background will consume the queue until a "None" message has been received.

  Make sure to run start_consuming() after initializing the instance of
  CloudLoggingCollector to start all necessary worker threads.

  Attributes:
    project: The project ID of the Google Cloud project to which logs are sent.
    log_name: The log ID of the log entry name.
    multiprocessing: If enabled, use multiprocessing to send logs to GCP. This
      speeds up Ansible execution significantly.
    ignore_errors: If enabled, GCP API errors are ignored and Ansible will not
      exit early.
    params: Parameters for the GcpSession class.
    queue: The message queue for multiprocessing.
    logging: The GcpSession instance for sending logs to GCP.
    consumer: The thread consuming messages from the queue.
  """

  def __init__(
      self,
      project: str,
      log_name: str,
      multiprocessing: bool,
      ignore_errors: bool = False,
  ):
    """Initializes the CloudLoggingCollector instance.

    Args:
      project: The project ID of the Google Cloud project to which logs are
        sent.
      log_name: The log ID of the log entry name.
      multiprocessing: If enabled, use multiprocessing to send logs to GCP. This
        speeds up Ansible execution significantly.
      ignore_errors: If enabled, GCP API errors are ignored and Ansible will not
        exit early.
    """
    self.project = project
    self.log_name = log_name
    self.multiprocessing = multiprocessing
    self.ignore_errors = ignore_errors
    # We have to define params for the GcpSession class.
    # For some reason, it throws an error if these params are not defined.
    self.params = {
        "auth_kind": "application",
        "scopes": "https://www.googleapis.com/auth/logging.write",
    }
    self.logging = GcpSession(self, "logging")
    if self.multiprocessing:
      self.queue = queue.Queue()

  def fail_json(self, **kwargs) -> None:
    raise RuntimeError(kwargs.get("msg", "GCP Logging callback failed"))

  def start_consuming(self) -> None:
    """If multiprocessing enabled this function setups consumer and queue.

    If multiprocessing is disabled, this function is a no-op. We do not log
    disabled multiprocessing to not destroy the Ansible CLI output.
    """
    if self.multiprocessing:
      self.consumer = threading.Thread(target=self.consume)
      self.consumer.start()

  def _send(
      self,
      payload: (
          PlaybookStartMessage
          | PlaybookTaskStartMessage
          | PlaybookTaskEndMessage
          | PlaybookEndMessage
      ),
  ) -> None:
    """Sends a log entry to GCP Logging."""
    entry = {
        "logName": f"projects/{self.project}/logs/{self.log_name}",
        "resource": {
            "type": "global",
            "labels": {
                "project_id": self.project,
            },
        },
        "jsonPayload": payload,
    }
    entries = {"entries": [entry]}
    resp = self.logging.full_post(
        "https://logging.googleapis.com/v2/entries:write",
        json=entries,
    )
    if resp.status_code != 200:
      print(
          f"Received status code {resp.status_code} for log entry:"
          f" {resp.json()}"
      )
      if not self.ignore_errors:
        print(
            "The Ansible playbook execution was terminated due to an error"
            " encountered while attempting to send execution logs to Cloud. For"
            " detailed information regarding the error, please refer to the"
            " following link: go/sap-ansible#ansible-logging",
            file=sys.stderr,
        )
        sys.exit(1)

  def send(
      self,
      payload: (
          PlaybookStartMessage
          | PlaybookTaskStartMessage
          | PlaybookTaskEndMessage
          | PlaybookEndMessage
          | None
      ),
  ) -> None:
    """Public send method to add a new log message to the queue.

    Args:
      payload: The payload to be sent to GCP Logging.
    """
    if self.multiprocessing:
      self.queue.put(payload)
      return
    self._send(payload)

  def consume(self):
    """Consumes messages from the queue and sends them to GCP Logging."""
    while True:
      msg = self.queue.get()
      # if msg is None ensures that we break out of the loop to finish the
      # consumer thread, because join() only finishes when the consumer thread
      # is dead.
      if msg is None:
        break
      self._send(msg)
      self.queue.task_done()

  def wait(self):
    """Waits for the consumer thread to finish."""
    # join() only finishes when the consumer thread finishes not when the queue
    # itself is empty.
    self.consumer.join()


class CallbackModule(callback.CallbackBase):
  """Ansible callback plugin to get execution data and invoke CloudLogging writer."""

  def __init__(self, display=None):
    super().__init__(display)
    # Required for collecting options set via environment variables.
    self.id = str(uuid.uuid4())
    self.start_time = self._time_now()
    self.user = getpass.getuser()
    self.start_msg = PlaybookStartMessage(
        id="",
        event_type="PLAYBOOK_START",
        user="",
        start_time="",
        playbook_name="",
        playbook_basedir="",
        inventories=[],
        extra_vars={},
        check=False,
        limit="",
        env={},
    )
    # self.tasks is a dictionary of tasks where key is (host, task_id).
    # We use (host, task_id) for identifying a task because a task with
    # the same ID can run on multiple hosts.
    self.tasks = {}
    # The DOCUMENTATION string works as default for the options specified
    # here.
    self.set_options()
    self.project = self.get_option("project")
    self.log_name = self.get_option("log_name")
    self.ignore_errors = convert_bool.boolean(self.get_option("ignore_errors"))
    self.print_uuid = convert_bool.boolean(self.get_option("print_uuid"))
    self.multiprocessing = convert_bool.boolean(
        self.get_option("multiprocessing")
    )

    self.logging_collector = CloudLoggingCollector(
        project=self.project,
        log_name=self.log_name,
        multiprocessing=self.multiprocessing,
        ignore_errors=self.ignore_errors,
    )
    self.logging_collector.start_consuming()

    if self.print_uuid:
      # We register the _print_uuid function with atexit, because we want to
      # ensure that this function gets called at the end of the whole Ansible
      # execution and AFTER all other stdout or stderrr output.
      atexit.register(_print_uuid, self.id)

  def set_options(
      self,
      task_keys: Optional[Dict[str, str]] = None,
      var_options: Optional[Dict[str, str]] = None,
      direct: Optional[Dict[str, str]] = None,
  ) -> None:
    """Sets the option for the callback module. Will be called by Ansible.

    Args:
      task_keys: Only passed through.
      var_options: Only passed through.
      direct: Only passed through.
    """
    super().set_options(
        task_keys=task_keys, var_options=var_options, direct=direct
    )

  def _time_now(self) -> str:
    """Returns the current ISO 8601 timestamp for the UTC timezone.

    Returns:
      A string representing the current datetime in the format ISO 8601 UTC.
    """
    return f"{datetime.datetime.now(datetime.timezone.utc).isoformat()}"

  def _filter_env(self, env: dict[str, str]) -> dict[str, str]:
    """Filters out the environment variables that are not needed.

    Args:
      env: The environment variables set for the playbook execution.

    Returns:
      A dictionary containing the filtered environment variables.
    """
    wanted_prefix = ("ANSIBLE", "BORG", "WETLAB", "GUITAR", "GCE", "SENSIBLE")
    return {
        k: v
        for k, v in env.items()
        if k.startswith(wanted_prefix) or k in {"PATH", "USER"}
    }

  def _store_result_in_task(
      self, result: ansible.executor.task_result.TaskResult, status: str
  ) -> None:
    """Helper function to store a result into an already existing task.

    We find the correct task by looking it up via the task ID and the host name.

    Args:
      result: The result object of type ansible.executor.result.Result
      status: The status of the task (OK, FAILED, SKIPPED, etc.)
    """
    host = result._host
    task = result._task
    self.tasks[(host.get_name(), task._uuid)]["result"] = result._result.copy()
    self.tasks[(host.get_name(), task._uuid)]["end_time"] = self._time_now()
    self.tasks[(host.get_name(), task._uuid)]["status"] = status
    self.logging_collector.send(self.tasks[(host.get_name(), task._uuid)])

  def v2_playbook_on_start(self, playbook: ansible.playbook.Playbook) -> None:
    """Plugin function that gets called when a playbook starts.

    v2_playbook_on_start gets called before any host connection.
    We plug into this function to log the playbook start.

    Args:
      playbook: ansible.playbook.Playbook.
    """
    self.start_msg["user"] = self.user
    self.start_msg["start_time"] = self.start_time
    self.start_msg["id"] = self.id
    self.start_msg["env"] = self._filter_env(
        os.environ.copy()
    )  # create a copy to avoid accidentally writing to global env
    self.start_msg["playbook_name"] = playbook._file_name.rpartition("/")[2]
    self.start_msg["playbook_basedir"] = playbook._basedir
    if context.CLIARGS.get("inventory", False):
      self.start_msg["inventories"] = list(context.CLIARGS["inventory"])
    if context.CLIARGS.get("subset", False):
      self.start_msg["limit"] = context.CLIARGS["subset"]
    if context.CLIARGS.get("check", False):
      self.start_msg["check"] = context.CLIARGS["check"]

  def v2_playbook_on_play_start(self, play: ansible.playbook.Play) -> None:
    """Plugin function that gets called when first connections are made.

    This function is required, because it has access to the variable manager
    which contains the extra_vars.

    Args:
      play: ansible.playbook.Play.
    """
    vm = play.get_variable_manager()
    self.start_msg["extra_vars"] = vm.extra_vars
    self.logging_collector.send(self.start_msg)

  def v2_runner_on_start(
      self, host: ansible.inventory.host.Host, task: ansible.playbook.task.Task
  ) -> None:
    """Plugin function that gets called when a task starts.

    Args:
      host: The host object of type ansible.host.host
      task: The task object of type ansible.executor.task.Task
    """
    time_now = self._time_now()
    self.logging_collector.send(
        PlaybookTaskStartMessage(
            id=self.id,
            event_type="PLAYBOOK_TASK_START",
            task_id=task._uuid,
            name=task.get_name(),
            host=host.get_name(),
            start_time=time_now,
        )
    )

    # Starts constructing event for task end.
    t = PlaybookTaskEndMessage(
        id="",
        event_type="PLAYBOOK_TASK_END",
        task_id="",
        name="",
        host="",
        start_time="",
        end_time="",
        status="",
        result={},
    )
    t["id"] = self.id
    t["task_id"] = task._uuid
    t["name"] = task.get_name()
    t["host"] = host.get_name()
    t["start_time"] = time_now
    self.tasks[(host.get_name(), task._uuid)] = t

  def v2_runner_on_failed(
      self,
      result: ansible.executor.task_result.TaskResult,
      ignore_errors: bool = False,
  ) -> None:
    """Plugin function that gets called when a task fails.

    Args:
      result: The result object of type ansible.executor.result.Result
      ignore_errors: If set to True, no errors are processed. We set this to
        False on default, because we always want to process errors.
    """
    self._store_result_in_task(result, "FAILED")

  def v2_runner_on_ok(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task succeeds."""
    self._store_result_in_task(result, "OK")

  def v2_runner_on_skipped(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task is skipped.

    Args:
      result: The result object of type ansible.executor.result.Result
    """
    self._store_result_in_task(result, "SKIPPED")

  def v2_runner_on_unreachable(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task is unreachable.

    Args:
      result: The result object of type ansible.executor.result.Result
    """
    self._store_result_in_task(result, "UNREACHABLE")

  def v2_playbook_on_stats(
      self, stats: ansible.executor.stats.AggregateStats
  ) -> None:
    """Plugin function that gets called when a playbook ends.

    v2_playbook_on_stats gets called after all hosts have been processed.
    We plug into this function to log the playbook end. It is also the point
    in time where the Ansible execution ends, so we have to wait until
    the queue has been fully consumed.

    Args:
      stats: The stats object of type ansible.executor.stats.AggregateStats
    """
    msg = PlaybookEndMessage(
        id="",
        event_type="PLAYBOOK_END",
        user="",
        start_time="",
        end_time="",
        stats={},
    )
    hosts = sorted(stats.processed.keys())
    summary = {}
    for h in hosts:
      s = stats.summarize(h)
      summary[h] = s
    msg["id"] = self.id
    msg["user"] = self.user
    msg["start_time"] = self.start_time
    msg["end_time"] = self._time_now()
    msg["stats"] = summary
    self.logging_collector.send(msg)
    if self.multiprocessing:
      self.logging_collector.send(None)
      self.logging_collector.wait()
