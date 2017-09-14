include RollingRestart

action :release do
  require 'aws-sdk'
  dynamodb_client = Aws::DynamoDB::Client.new(region: 'us-east-1')

  setup_table(dynamodb_client)
  release_lock(dynamodb_client, new_resource.lock_name, nil)
  new_resource.updated_by_last_action(true)
end

action :execute do
  require 'aws-sdk'
  dynamodb_client = Aws::DynamoDB::Client.new(region: 'us-east-1')

  setup_table(dynamodb_client)

  # we want to handle retries ourselves here
  old_http_retry_count = Chef::Config[:http_retry_count]
  Chef::Config[:http_retry_count] = 0

  begin
    acquire_lock(
      dynamo_db: dynamodb_client,
      lock_name: new_resource.lock_name,
      timeout: new_resource.timeout,
      polling_interval: new_resource.polling_interval,
      context: run_context,
    )
    recipe_eval(&new_resource.recipe)
  ensure
    release_lock(dynamodb_client, new_resource.lock_name, run_context)
    # clean up our change to the http_retry_count
    Chef::Config[:http_retry_count] = old_http_retry_count
  end
end
