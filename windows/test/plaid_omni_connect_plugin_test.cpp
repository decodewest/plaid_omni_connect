#include "../../common/plaid_link_message.h"

#include <gtest/gtest.h>

TEST(PlaidLinkMessage, TerminalStatesCloseTheHost) {
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"type\":\"success\",\"publicToken\":\"public-sandbox\"}"));
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"error\":null,\"type\":\"exit\",\"metadata\":{\"status\":\"\"}}"));
  EXPECT_TRUE(plaid_link_message_is_terminal(
      "{\"type\":\"error\",\"error\":\"WebView2 runtime is unavailable\"}"));
  EXPECT_FALSE(plaid_link_message_is_terminal(
      "{\"type\":\"event\",\"eventName\":\"OPEN\",\"metadata\":{\"view_name\":\"CONSENT\"}}"));
  EXPECT_FALSE(plaid_link_message_is_terminal(nullptr));
}

TEST(PlaidLinkMessage, EventsStayOpenEvenWhenMetadataMentionsExit) {
  EXPECT_FALSE(plaid_link_message_is_terminal(
      "{\"type\":\"event\",\"eventName\":\"ERROR\",\"metadata\":{\"error_code\":\"INVALID_LINK_TOKEN\"}}"));
}
