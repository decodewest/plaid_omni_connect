#include "../../common/plaid_link_message.h"

#include <gtest/gtest.h>

TEST(PlaidLinkMessage, TerminalStatesCloseTheHost) {
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"type\":\"success\",\"publicToken\":\"public-sandbox\"}"));
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"error\":null,\"type\":\"exit\",\"metadata\":{\"status\":\"\"}}"));
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"type\":\"error\",\"error\":\"Link page failed\"}"));
  EXPECT_FALSE(plaid_link_message_is_terminal(
      "{\"type\":\"event\",\"eventName\":\"OPEN\"}"));
  EXPECT_FALSE(plaid_link_message_is_terminal(nullptr));
}
