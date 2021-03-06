Feature: Cloud Trail

#  Scenario: Get default cloud trail for region if no bucket name or trail name given
#    Given I double `aws cloudtrail describe-trails --region us-west-1` with stdout:
#    """
#    {
#      "trailList": [
#        { "Name": "dontGetMe", "S3BucketName": "dontUseMe"},
#        { "Name": "default", "S3BucketName": "bucketName"}
#      ]
#    }
#    """
#    And I double `aws s3 sync bucketName ~/.zaws/s3-cache/bucketName/ --region us-west-1` with "~/.zaws/s3-cache/bucketName/"
#    And a gzip file named "~/.zaws/s3-cache/bucketName/test" with:
#    """
#    {"Results":"testResults"}
#    """
#    When I run `bundle exec zaws cloud_trail view --region us-west-1  --raw`
#    Then the output should contain:
#    """
#    {"Results":"testResults"}
#    """
#
#  Scenario: Get specified cloud trail for region if trail name given
#    Given I double `aws cloudtrail describe-trails --region us-west-1` with stdout:
#    """
#    {
#      "trailList": [
#        { "Name": "namedTrail", "S3BucketName": "bucketName"},
#        { "Name": "default", "S3BucketName": "dontUseMe"}
#      ]
#    }
#    """
#    And I double `aws s3 sync bucketName ~/.zaws/s3-cache/bucketName/ --region us-west-1` with "~/.zaws/s3-cache/bucketName/"
#    and a gzip file named "~/.zaws/s3-cache/bucketName/test" with:
#    """
#    {"Results":"testResults"}
#    """
#    When I run `bundle exec zaws cloud_trail view --region us-west-1 --trailName namedTrail  --raw`
#    Then the output should contain:
#    """
#    {"Results":"testResults"}
#    """
#
#  Scenario: Get specified cloud trail for region if bucket name given
#    Given I double `aws s3 sync bucketName ~/.zaws/s3-cache/bucketName/ --region us-west-1` with "Not Relevant"
#    and a gzip file named "~/.zaws/s3-cache/bucketName/someFile" with:
#    """
#    {"Results":"testResults"}
#    """
#    When I run `bundle exec zaws cloud_trail view --region us-west-1 --bucket bucketName  --raw`
#    Then the output should contain:
#    """
#    {"Results":"testResults"}
#    """
#
#  Scenario: Get specified cloud trail by bucket name and consolidate all json logs into a single json
#    Given I double `aws s3 sync bucketName ~/.zaws/s3-cache/bucketName/ --region us-west-1` with "Not Relevant"
#    and a gzip file named "~/.zaws/s3-cache/bucketName/topLevelFile" with:
#    """
#    {"Results":"firstFileResults"}
#    """
#    and a gzip file named "~/.zaws/s3-cache/bucketName/someDir/nestedFile" with:
#    """
#    {"Results":"secondFileResults"}
#    """
#    and a gzip file named "~/.zaws/s3-cache/bucketName/someOtherDir/anotherDir/anotherNestedFile" with:
#    """
#    {"Results":"thirdFileResults"}
#    """
#    When I run `bundle exec zaws cloud_trail view --region us-west-1 --bucket bucketName  --raw`
#    Then the output should contain:
#    """
#    {"Results":"firstFileResults"}
#    """
#    Then the output should contain:
#    """
#    {"Results":"secondFileResults"}
#    """
#    Then the output should contain:
#    """
#    {"Results":"thirdFileResults"}
#    """
#
#  Scenario: Declare a CloudTrail by name but skip actual creation because it already exists
#    Given I double `aws cloudtrail describe-trails --region us-west-1` with stdout:
#    """
#    {
#      "trailList": [
#        { "Name": "test-cloudtrail", "S3BucketName": "does-not-matter"}
#      ]
#    }
#    """
#    When I run `bundle exec zaws cloud_trail declare test-cloudtrail --region us-west-1`
#    Then the output should contain "CloudTrail already exists. Creation skipped.\n"
#
#  Scenario: Declare a CloudTrail by name that is actually created because it doesn't yet exist
#    Given I double `aws cloudtrail describe-trails --region us-west-1` with stdout:
#    """
#    {
#      "trailList": []
#    }
#    """
#    And I double `aws --region us-west-1 cloudtrail create-subscription --name test-cloudtrail --s3-new-bucket zaws-cloudtrail-test-cloudtrail` with stdout:
#    """
#Setting up new S3 bucket zaws-cloudtrail-test-cloudtrail...
#Creating/updating CloudTrail configuration...
#CloudTrail configuration:
#{
#  "trailList": [
#    {
#      "IncludeGlobalServiceEvents": true,
#      "Name": "test-cloudtrail",
#      "S3BucketName": "zaws-cloudtrail-test-cloudtrail"
#    }
#  ]
#}
#Starting CloudTrail service...
#Logs will be delivered to zaws-cloudtrail-test-cloudtrail:
#    """
#    When I run `bundle exec zaws cloud_trail declare test-cloudtrail --region us-west-1`
#    Then the output should contain "Logs will be delivered to zaws-cloudtrail-test-cloudtrail"
#

