import unittest
from subprocess import CompletedProcess
from unittest.mock import call, patch

from utils.haproxy_batch_state import HaproxyTarget, main, parse_show_servers_state, verify_target_states


SHOW_SERVERS_STATE_OUTPUT = """1
# be_id be_name srv_id srv_name srv_addr srv_op_state srv_admin_state srv_uweight srv_iweight srv_time_since_last_change srv_check_status srv_check_result srv_check_health srv_check_state srv_agent_state bk_f_forced_id srv_f_forced_id srv_fqdn srv_port srvrecord srv_use_ssl srv_check_port srv_check_addr srv_agent_addr srv_agent_port
4 app_django 1 happ-web-01 65.109.136.108 2 1 1 1 496 15 3 4 6 0 0 0 happ-web-01.node.nyc1.consul 8000 - 0 0 - - 0
4 app_django 2 happ-web-02 65.108.95.96 2 0 1 1 406 15 3 4 6 0 0 0 happ-web-02.node.nyc1.consul 8000 - 0 0 - - 0
"""

SHOW_SERVERS_STATE_OUTPUT_ALL_MAINT = """1
# be_id be_name srv_id srv_name srv_addr srv_op_state srv_admin_state srv_uweight srv_iweight srv_time_since_last_change srv_check_status srv_check_result srv_check_health srv_check_state srv_agent_state bk_f_forced_id srv_f_forced_id srv_fqdn srv_port srvrecord srv_use_ssl srv_check_port srv_check_addr srv_agent_addr srv_agent_port
4 app_django 1 happ-web-01 65.109.136.108 2 1 1 1 496 15 3 4 6 0 0 0 happ-web-01.node.nyc1.consul 8000 - 0 0 - - 0
4 app_django 2 happ-web-02 65.108.95.96 2 1 1 1 406 15 3 4 6 0 0 0 happ-web-02.node.nyc1.consul 8000 - 0 0 - - 0
"""


class Test_HaproxyBatchState(unittest.TestCase):
    def test_parse_show_servers_state_keeps_first_server_after_version_preamble(self):
        states = parse_show_servers_state(SHOW_SERVERS_STATE_OUTPUT)

        self.assertEqual(states[("app_django", "happ-web-01")], "1")
        self.assertEqual(states[("app_django", "happ-web-02")], "0")

    def test_verify_target_states_reports_missing_first_server_as_failure(self):
        states = parse_show_servers_state(SHOW_SERVERS_STATE_OUTPUT)

        verify_target_states(
            [HaproxyTarget("app_django", "happ-web-01")],
            states,
            expected_admin_state="1",
        )

        with self.assertRaisesRegex(RuntimeError, "app_django/happ-web-01"):
            verify_target_states(
                [HaproxyTarget("app_django", "happ-web-01")],
                states,
                expected_admin_state="0",
            )

    @patch("utils.haproxy_batch_state.run_haproxy_commands")
    def test_main_uses_one_socket_call_per_target_then_reads_state_once(self, mock_run_haproxy_commands):
        mock_run_haproxy_commands.side_effect = [
            CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            CompletedProcess(args=[], returncode=0, stdout=SHOW_SERVERS_STATE_OUTPUT_ALL_MAINT, stderr=""),
        ]

        result = main(["maint", "app_django/happ-web-01", "app_django/happ-web-02"])

        self.assertEqual(result, 0)
        self.assertEqual(
            mock_run_haproxy_commands.call_args_list,
            [
                call(["set server app_django/happ-web-01 state maint"]),
                call(["set server app_django/happ-web-02 state maint"]),
                call(["show servers state"]),
            ],
        )


if __name__ == "__main__":
    unittest.main()
