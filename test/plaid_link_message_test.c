#include <assert.h>
#include <stdio.h>

#include "../common/plaid_link_message.h"

int main(void) {
  assert(plaid_link_message_is_terminal(
      "{\"type\":\"success\",\"publicToken\":\"public-sandbox\"}"));
  assert(plaid_link_message_is_terminal(
      "{\"error\":null,\"type\":\"exit\",\"metadata\":{\"status\":\"\"}}"));
  assert(plaid_link_message_is_terminal(
      "{\"type\":\"error\",\"error\":\"WebView2 runtime is unavailable\"}"));
  assert(!plaid_link_message_is_terminal(
      "{\"type\":\"event\",\"eventName\":\"OPEN\",\"metadata\":{\"view_name\":\"CONSENT\"}}"));
  assert(!plaid_link_message_is_terminal(NULL));
  assert(!plaid_link_message_is_terminal(""));
  puts("plaid_link_message_test ok");
  return 0;
}
