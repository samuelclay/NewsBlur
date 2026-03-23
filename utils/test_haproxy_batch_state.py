import unittest

from utils.haproxy_batch_state import HaproxyTarget, parse_show_servers_state, verify_target_states


SHOW_SERVERS_STATE_OUTPUT = """1
# be_id be_name srv_id srv_name srv_addr srv_op_state srv_admin_state srv_uweight srv_iweight srv_time_since_last_change srv_check_status srv_check_result srv_check_health srv_check_state srv_agent_state bk_f_forced_id srv_f_forced_id srv_fqdn srv_port srvrecord srv_use_ssl srv_check_port srv_check_addr srv_agent_addr srv_agent_port
4 app_django 1 happ-web-01 65.109.136.108 2 1 1 1 496 15 3 4 6 0 0 0 happ-web-01.node.nyc1.consul 8000 - 0 0 - - 0
4 app_django 2 happ-web-02 65.108.95.96 2 0 1 1 406 15 3 4 6 0 0 0 happ-web-02.node.nyc1.consul 8000 - 0 0 - - 0
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


if __name__ == "__main__":
    unittest.main()
