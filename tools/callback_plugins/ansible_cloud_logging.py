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

# Ansible plugins and modules import utilities from a special namespace that doesn't
# follow standard Python import behavior. At runtime, Ansible dynamically builds this
# namespace (ansible_collections) by combining built-in utilities and any found in installed collections.
# You must run the plugin within Ansible for the imports to work correctly.
# Ansible sets up the import paths and injects collection-based utilities at runtime.
# See more details here: https://docs.ansible.com/ansible/latest/dev_guide/developing_module_utilities.html#using-and-developing-module-utilities.
from ansible.module_utils.parsing import convert_bool
from ansible.plugins import callback
from ansible_collections.google.cloud.plugins.module_utils.gcp_utils import GcpSession


DOCUMENTATION = """
  name: ansible_cloud_logging
  type: aggregate
  options:
    project:
      description: The Google Cloud project ID where logs will be sent.
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
    ignore_gcp_api_errors:
      description: If enabled (default) GCP API errors are ignored and do not cause Ansible to fail.
      type: bool
      default: True
      env:
        - name: ANSIBLE_CLOUD_LOGGING_IGNORE_GCP_API_ERRORS
      ini:
        - section: cloud_logging
          key: ignore_gcp_api_errors
    print_uuid:
      description: If enabled, print the UUID of the Playbook execution.
      type: bool
      default: False
      env:
        - name: ANSIBLE_CLOUD_LOGGING_PRINT_UUID
      ini:
        - section: cloud_logging
          key: print_uuid
    enable_async_logging:
      description: If True, log messages are queued and sent by a background thread 
        to avoid blocking Ansible execution. If False, messages are sent
        synchronously as they are emitted.
      type: bool
      default: True
      env:
        - name: ANSIBLE_CLOUD_LOGGING_ENABLE_ASYNC_LOGGING
      ini:
        - section: cloud_logging
          key: enable_async_logging
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
  # WLM fields
  deployment_name: str
  state: str
  timestamp: str
  file_name: str
  base_dir: str


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
  # WLM fields
  deployment_name: str
  state: str
  timestamp: str
  step_name: str


# Not supported by WLM
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
  # WLM fields
  deployment_name: str
  state: str
  timestamp: str
  playbook_stats: dict[str, Any]


class CloudLoggingCollector:
  """Provides a thread for collecting and sending logs to Google Cloug Logging.

  Create a new CloudLoggingCollector instance by passing the project and
  the log_name. Log messages can be submitted using CloudLoggingCollector.send(msg). 
  If enable_async_logging is set to True, messages are queued and processed by 
  a background thread started via start_consuming(). Otherwise, messages are sent synchronously. 
  The separate worker thread running in the background will consume the queue 
  until a "None" message has been received. Make sure to run start_consuming() 
  after initializing the instance of CloudLoggingCollector to start all necessary worker threads.

  Attributes:
    project: The Google Cloud project ID where logs will be sent.
    log_name: The log ID of the log entry name.
    enable_async_logging: If True, log messages are queued and sent by a background thread 
      to avoid blocking Ansible execution. If False, messages are sent
      synchronously as they are emitted.
    ignore_gcp_api_errors: If enabled, GCP API errors are ignored and do not cause Ansible to fail.
    params: Parameters for the GcpSession class.
    queue: Holds log messages when async logging is enabled.
    gcp_session: Handles authenticated communication with the Google Cloud Logging API.
    consumer: Background thread that processes log messages from the queue.
  """

  def __init__(
      self,
      project: str,
      log_name: str,
      enable_async_logging: bool,
      ignore_gcp_api_errors: bool = False,
  ):
    """Initializes the CloudLoggingCollector instance.

    Args:
      project: The Google Cloud project ID where logs will be sent.
      log_name: The log ID of the log entry name.
      enable_async_logging: If True, log messages are queued and sent by a background thread 
        to avoid blocking Ansible execution. If False, messages are sent
        synchronously as they are emitted.
      ignore_gcp_api_errors: If enabled, GCP API errors are ignored and do not cause Ansible to fail.
    """
    self.project = project
    self.log_name = log_name
    self.enable_async_logging = enable_async_logging
    self.ignore_gcp_api_errors = ignore_gcp_api_errors
    self.params = {
        "auth_kind": "application",
        "scopes": "https://www.googleapis.com/auth/logging.write",
    }
    self.gcp_session = GcpSession(self, "logging")
    if self.enable_async_logging:
      self.queue = queue.Queue()

  def fail_json(self, **kwargs) -> None:
    raise RuntimeError(kwargs.get("msg", "An error occurred, but no message was provided"))

  def start_consuming(self) -> None:
    """Starts the background consumer thread.

    If enable_async_logging is False, the method, is a no-op.
    """
    if self.enable_async_logging:
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
    """Sends a log entry to Google Cloud Logging."""
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
    resp = self.gcp_session.full_post(
        "https://logging.googleapis.com/v2/entries:write",
        json=entries,
    )
    if resp.status_code != 200:
      print(
          f"Received status code {resp.status_code} for log entry:"
          f" {resp.json()}"
      )
      if not self.ignore_gcp_api_errors:
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
      payload: The payload to be sent to Google Cloug Logging.
    """
    if self.enable_async_logging:
      self.queue.put(payload)
      return
    self._send(payload)

  def consume(self):
    """Consumes messages from the queue and sends them to Google Cloug Logging."""
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
  """Ansible callback plugin that sends playbook logs to Google Cloud Logging in JSON format."""

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
    # Convert string value from ansible.cfg to a proper boolean
    self.ignore_gcp_api_errors = convert_bool.boolean(self.get_option("ignore_gcp_api_errors"))
    self.print_uuid = convert_bool.boolean(self.get_option("print_uuid"))
    self.enable_async_logging = convert_bool.boolean(
        self.get_option("enable_async_logging")
    )
    # The optional deployment_name is passed in by Terraform.
    self.deployment_name = os.environ.get("DEPLOYMENT_NAME", "UNSET_DEPLOYMENT_NAME")

    self.logging_collector = CloudLoggingCollector(
        project=self.project,
        log_name=self.log_name,
        enable_async_logging=self.enable_async_logging,
        ignore_gcp_api_errors=self.ignore_gcp_api_errors,
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
    """Called by Ansible to initialize the callback plugin's configuration options.

      This method sets internal options from Ansible's config system (e.g., ansible.cfg,
      extra vars, or direct settings). Use self.get_option(<option_name>) to access these
      values.

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
    """Filters out unnecessary environment variables before sending to Google Cloud Logging.

    Args:
      env: A dictionary of environment variables available during playbook execution.

    Returns:
      A new dictionary containing only the environment variables relevant for logging.
    """
    wanted_prefix = ("ANSIBLE")
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
    # WLM fields
    self.start_msg["deployment_name"] = self.deployment_name
    self.start_msg["state"] = "playbook_start"
    self.start_msg["timestamp"] = self.start_time
    self.start_msg["file_name"] = playbook._file_name.rpartition("/")[2]
    self.start_msg["base_dir"] = playbook._basedir

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
            # WLM fields
            state="task_start",
            deployment_name=self.deployment_name,
            timestamp=time_now,
            step_name=task.get_name(),
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
        # WLM fields
        state="task_end",
        step_name="",
        timestamp="",
        deployment_name="",
    )
    t["id"] = self.id
    t["task_id"] = task._uuid
    t["name"] = task.get_name()
    t["host"] = host.get_name()
    t["start_time"] = time_now
    # WLM fields
    t["step_name"] = task.get_name()
    t["timestamp"] = time_now
    t["deployment_name"] = self.deployment_name
    t["step_name"] = task.get_name()
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
    self._store_result_in_task(result, "failed")

  def v2_runner_on_ok(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task succeeds."""
    # WLM expects "success" instead of Ansible's "OK"
    self._store_result_in_task(result, "success")

  def v2_runner_on_skipped(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task is skipped.

    Args:
      result: The result object of type ansible.executor.result.Result
    """
    self._store_result_in_task(result, "skipped")

  def v2_runner_on_unreachable(
      self, result: ansible.executor.task_result.TaskResult
  ) -> None:
    """Plugin function that gets called when a task is unreachable.

    Args:
      result: The result object of type ansible.executor.result.Result
    """
     # WLM expects "failed" instead of Ansible's "UNREACHABLE"
    self._store_result_in_task(result, "failed")

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
        # WLM fields
        state="playbook_end",
        deployment_name="",
        timestamp="",
        playbook_stats={},
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
    # WLM fields
    msg["deployment_name"] = self.deployment_name
    msg["timestamp"] = self._time_now()
    msg["playbook_stats"] = summary 
    self.logging_collector.send(msg)
    if self.enable_async_logging:
      self.logging_collector.send(None)
      self.logging_collector.wait()
