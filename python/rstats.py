# given SID, dump status

#!/usr/bin/env python3

import argparse
import json
import sys
from datetime import date, datetime
from typing import Any, Iterator, Sequence

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
    NoCredentialsError,
    ProfileNotFound,
)


# DescribeConfigRuleEvaluationStatus accepts no more than 25 rule names
# in a single request.
STATUS_REQUEST_BATCH_SIZE = 25

# Fields returned by DescribeConfigRuleEvaluationStatus.
# Using this list ensures missing fields appear as null in the JSON output.
STATUS_FIELDS = (
    "ConfigRuleName",
    "ConfigRuleArn",
    "ConfigRuleId",
    "LastSuccessfulInvocationTime",
    "LastFailedInvocationTime",
    "LastSuccessfulEvaluationTime",
    "LastFailedEvaluationTime",
    "FirstActivatedTime",
    "LastDeactivatedTime",
    "LastErrorCode",
    "LastErrorMessage",
    "FirstEvaluationStarted",
    "LastDebugLogDeliveryStatus",
    "LastDebugLogDeliveryStatusReason",
    "LastDebugLogDeliveryTime",
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Find AWS Config rules by SourceIdentifier and display their "
            "evaluation status."
        )
    )

    parser.add_argument(
        "source_identifier",
        metavar="SOURCE_IDENTIFIER",
        help=(
            "AWS Config managed-rule source identifier, for example "
            "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
        ),
    )

    parser.add_argument(
        "region",
        metavar="REGION",
        help="AWS Region to query, for example us-east-1",
    )

    parser.add_argument(
        "--profile",
        help="Optional AWS CLI named profile",
    )

    parser.add_argument(
        "--compact",
        action="store_true",
        help="Produce compact JSON instead of indented JSON",
    )

    return parser.parse_args()


def json_serializer(value: Any) -> str:
    """Convert boto3 datetime values into ISO 8601 strings."""
    if isinstance(value, (datetime, date)):
        return value.isoformat()

    raise TypeError(
        f"Object of type {type(value).__name__} is not JSON serializable"
    )


def chunked(
    values: Sequence[str],
    size: int,
) -> Iterator[Sequence[str]]:
    """Yield fixed-size slices from a sequence."""
    for index in range(0, len(values), size):
        yield values[index : index + size]


def create_config_client(
    region: str,
    profile: str | None,
) -> Any:
    """Create an AWS Config boto3 client."""
    session_arguments: dict[str, str] = {
        "region_name": region,
    }

    if profile:
        session_arguments["profile_name"] = profile

    session = boto3.Session(**session_arguments)

    return session.client(
        "config",
        region_name=region,
    )


def find_matching_rules(
    config_client: Any,
    source_identifier: str,
) -> list[dict[str, Any]]:
    """
    Return every Config rule whose SourceIdentifier matches the requested
    identifier.
    """
    paginator = config_client.get_paginator("describe_config_rules")
    matching_rules: list[dict[str, Any]] = []

    for page in paginator.paginate():
        for rule in page.get("ConfigRules", []):
            source = rule.get("Source", {})

            if source.get("SourceIdentifier") == source_identifier:
                matching_rules.append(rule)

    matching_rules.sort(
        key=lambda rule: rule.get("ConfigRuleName", "")
    )

    return matching_rules


def get_evaluation_statuses(
    config_client: Any,
    rule_names: list[str],
) -> list[dict[str, Any]]:
    """
    Retrieve evaluation status for all matching rule names.

    Requests are divided into batches because the AWS API limits the number
    of rule names in one request.
    """
    statuses: list[dict[str, Any]] = []
    paginator = config_client.get_paginator(
        "describe_config_rule_evaluation_status"
    )

    for rule_name_batch in chunked(
        rule_names,
        STATUS_REQUEST_BATCH_SIZE,
    ):
        for page in paginator.paginate(
            ConfigRuleNames=list(rule_name_batch)
        ):
            statuses.extend(
                page.get("ConfigRulesEvaluationStatus", [])
            )

    statuses.sort(
        key=lambda status: status.get("ConfigRuleName", "")
    )

    return statuses


def normalize_status(
    status: dict[str, Any],
) -> dict[str, Any]:
    """
    Include all documented evaluation-status fields.

    Fields not returned by AWS are represented as null.
    Any future fields returned by AWS are also preserved.
    """
    normalized = {
        field: status.get(field)
        for field in STATUS_FIELDS
    }

    # Preserve any additional fields introduced by AWS in the future.
    for key, value in status.items():
        if key not in normalized:
            normalized[key] = value

    return normalized


def print_json(
    payload: dict[str, Any],
    compact: bool,
) -> None:
    """Print the result as valid JSON."""
    if compact:
        print(
            json.dumps(
                payload,
                default=json_serializer,
                separators=(",", ":"),
            )
        )
    else:
        print(
            json.dumps(
                payload,
                default=json_serializer,
                indent=4,
            )
        )


def report_errors(
    statuses: list[dict[str, Any]],
) -> int:
    """
    Write meaningful error descriptions to stderr.

    Returns:
        0 when no status contains LastErrorCode.
        2 when one or more statuses contain LastErrorCode.
    """
    error_statuses = [
        status
        for status in statuses
        if status.get("LastErrorCode")
    ]

    if not error_statuses:
        return 0

    print(
        (
            f"AWS Config reported evaluation errors for "
            f"{len(error_statuses)} rule(s):"
        ),
        file=sys.stderr,
    )

    for status in error_statuses:
        rule_name = status.get("ConfigRuleName", "UNKNOWN")
        error_code = status.get("LastErrorCode", "UNKNOWN")
        error_message = status.get(
            "LastErrorMessage",
            "AWS Config did not provide an error message.",
        )

        print(file=sys.stderr)
        print(f"Rule: {rule_name}", file=sys.stderr)
        print(f"Error code: {error_code}", file=sys.stderr)
        print("Error description:", file=sys.stderr)

        for line in str(error_message).splitlines():
            print(f"  {line}", file=sys.stderr)

        if error_code == "InvalidParameterValueException":
            print(
                "Interpretation: One or more rule parameters "
                "contain an invalid value.",
                file=sys.stderr,
            )

            if (
                "excludedPublicBuckets" in str(error_message)
                and "optional_string" in str(error_message)
            ):
                print(
                    (
                        'Likely cause: The placeholder "optional_string" '
                        "was deployed as the value of "
                        "excludedPublicBuckets."
                    ),
                    file=sys.stderr,
                )
                print(
                    (
                        "Remediation: Remove excludedPublicBuckets from "
                        "the conformance-pack template when no exclusions "
                        "are required, or replace it with a comma-separated "
                        "list of valid S3 bucket names."
                    ),
                    file=sys.stderr,
                )

    return 2


def main() -> int:
    args = parse_arguments()

    try:
        config_client = create_config_client(
            region=args.region,
            profile=args.profile,
        )

        matching_rules = find_matching_rules(
            config_client=config_client,
            source_identifier=args.source_identifier,
        )

        if not matching_rules:
            print(
                (
                    "ERROR: No AWS Config rules were found with "
                    f"SourceIdentifier={args.source_identifier!r} "
                    f"in region {args.region!r}."
                ),
                file=sys.stderr,
            )
            return 1

        rule_names = [
            rule["ConfigRuleName"]
            for rule in matching_rules
            if rule.get("ConfigRuleName")
        ]

        statuses = get_evaluation_statuses(
            config_client=config_client,
            rule_names=rule_names,
        )

        normalized_statuses = [
            normalize_status(status)
            for status in statuses
        ]

        output = {
            "SourceIdentifier": args.source_identifier,
            "Region": args.region,
            "MatchingRuleCount": len(matching_rules),
            "EvaluationStatusCount": len(normalized_statuses),
            "ConfigRulesEvaluationStatus": normalized_statuses,
        }

        # JSON goes to stdout, making it available to pipeline consumers.
        print_json(
            payload=output,
            compact=args.compact,
        )

        # Human-readable errors go to stderr.
        return report_errors(statuses)

    except ProfileNotFound as error:
        print(
            f"ERROR: AWS profile was not found: {error}",
            file=sys.stderr,
        )
        return 1

    except NoCredentialsError:
        print(
            "ERROR: AWS credentials were not found.",
            file=sys.stderr,
        )
        return 1

    except ClientError as error:
        aws_error = error.response.get("Error", {})
        error_code = aws_error.get("Code", "UnknownClientError")
        error_message = aws_error.get("Message", str(error))

        print(
            f"ERROR: AWS API request failed: {error_code}",
            file=sys.stderr,
        )
        print(
            f"Description: {error_message}",
            file=sys.stderr,
        )
        return 1

    except BotoCoreError as error:
        print(
            f"ERROR: AWS SDK failure: {error}",
            file=sys.stderr,
        )
        return 1

    except KeyboardInterrupt:
        print(
            "ERROR: Operation interrupted.",
            file=sys.stderr,
        )
        return 130


if __name__ == "__main__":
    sys.exit(main())
