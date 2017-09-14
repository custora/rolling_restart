actions :execute, :clear

attribute :lock_name, kind_of: String, name_attribute: true
attribute :timeout, kind_of: Integer, default: 3600
attribute :polling_interval, kind_of: [Range, NilClass], default: nil

# no LWRP way to do this
def initialize(*args)
  super
  @action = :execute
end

# no LWRP way to do this either
def recipe(arg = nil, &block)
  arg ||= block
  set_or_return(
    :recipe,
    arg,
    kind_of: [Proc],
  )
end
