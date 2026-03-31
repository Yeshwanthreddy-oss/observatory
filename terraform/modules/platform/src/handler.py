"""Trivial sample Lambda handler for the observatory platform.

Deployed by Terraform against LocalStack as the demonstrable workload. It just
echoes the event back with a friendly message so an integrator can invoke it
and see a real response.
"""

import json


def handler(event, context):
    """Return a 200 response echoing the received event."""
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "hello from observatory sample lambda",
                "received_event": event,
            }
        ),
    }
