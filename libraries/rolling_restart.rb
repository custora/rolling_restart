require 'chef/data_bag'

module RollingRestart
  def release_lock(dynamo_db, lock_name, context)
    if context
      holder = "#{context.node.name} - #{context.node.ipaddress}"
      dynamo_db.delete_item(
        table_name: 'chef_rolling_restart_locks',
        key: {
          'lock_name' => lock_name,
        },
        condition_expression: 'lock_holder == :f',
        expression_attribute_values: {
          ':f' => holder,
        },
      )
    else
      dynamo_db.delete_item(
        table_name: 'chef_rolling_restart_locks',
        key: {
          'lock_name' => lock_name,
        },
      )
    end
  end

  def setup_table(dynamo_db)
    begin
      dynamo_db.create_table(
        table_name: 'chef_rolling_restart_locks',
        attribute_definitions: [
          { attribute_name: 'lock_name', attribute_type: 'S' },
        ],
        key_schema: [
          { attribute_name: 'lock_name', key_type: 'HASH' },
        ],
        provisioned_throughput: {
          read_capacity_units: 1,
          write_capacity_units: 1,
        },
      )
    rescue Aws::DynamoDB::Errors::ResourceInUseException
      # nada
    end

    dynamo_db.wait_until(:table_exists, table_name: 'chef_rolling_restart_locks')
  end

  def test_lock(dynamo_db, lock_name, holder)
    begin
      dynamo_db.put_item(
        table_name: 'chef_rolling_restart_locks',
        item: {
          'lock_name' => lock_name,
          'lock_holder' => holder,
        },
        condition_expression: 'lock_name <> :f',
        expression_attribute_values: {
          ':f' => lock_name,
        },
      )
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      return false
    end
    true
  end

  def current_lock_holder(dynamo_db, lock_name)
    response = dynamo_db.get_item(
      table_name: 'chef_rolling_restart_locks',
      key: {
        'lock_name' => lock_name,
      },
      consistent_read: true,
      attributes_to_get: ['lock_holder'],
    )
    response.item['lock_holder']
  end

  def wait_for_lock(dynamo_db, lock_name, timeout, context)
    holder = "#{context.node.name} - #{context.node.ipaddress}"
    start_time = Time.now
    time_expired = false
    until time_expired || test_lock(dynamo_db, lock_name, holder)
      Chef::Log.info("Waiting for rolling restart lock on #{lock_name}, currently held by #{current_lock_holder(dynamo_db, lock_name)}")
      sleep rand(5)
      time_expired = (Time.now - start_time) > timeout
    end
    if time_expired
      holder = current_lock_holder(dynamo_db, lock_name)
      Chef::Log.info("Time expired while waiting for rolling restart lock on #{lock_name}, currently held by #{holder}, FORCING RELEASE")
      release_lock(dynamo_db, lock_name)
      return false
    end
    true
  end

  def acquire_lock(dynamo_db, lock_name, timeout, holder)
    sleep(rand) until wait_for_lock(dynamo_db, lock_name, timeout, holder)
    Chef::Log.info("Acquired the lock for #{lock_name}")
  end
end
