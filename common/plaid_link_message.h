#ifndef PLAID_LINK_MESSAGE_H_
#define PLAID_LINK_MESSAGE_H_

#include <string.h>

/* True when the host should close Link. Event messages stay open.
   The page posts JSON from JSON.stringify with a "type" field of
   success, exit, error, or event. */
static int plaid_link_message_is_terminal(const char* json) {
  if (json == NULL) {
    return 0;
  }
  return strstr(json, "\"type\":\"success\"") != NULL ||
         strstr(json, "\"type\":\"exit\"") != NULL ||
         strstr(json, "\"type\":\"error\"") != NULL;
}

#endif /* PLAID_LINK_MESSAGE_H_ */
