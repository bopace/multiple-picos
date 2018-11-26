ruleset manage_fleet {
  meta {
    name "Manage Fleet"
    description <<
Manage Fleet ruleset for lab 7 - CS 462
>>
    author "Bo Pace"
    logging on
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
    shares vehicles
  }

  global {
    vehicles = function() {
      Subscriptions:established("Tx_role","vehicle")
    }

    get_subscription_by_name = function(name)  {
      ent:subs{name + "-sub"}
    }
  }

  rule create_vehicle {
    select when car new_vehicle name re#(.*)# setting(vehicle_name)
    fired {
      raise wrangler event "child_creation"
        attributes { "name": vehicle_name,
                     "type": "vehicle",
                     "color": "#ffb347",
                     "rids": ["track_trips", "trip_store"] }
    }
  }

  rule make_subscription {
    select when wrangler child_initialized
      name re#(.*)#
      parent_eci re#(.*)#
      eci re#(.*)#
        setting(sub_name, fleet_eci, vehicle_eci)
    event:send(
      { "eci": fleet_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": sub_name + "-sub",
                  "vehicle_name": sub_name,
                  "Rx_role": "fleet",
                  "Tx_role": "vehicle",
                  "channel_type": "subscription",
                  "wellKnown_Tx": vehicle_eci } } )
  }

  rule save_sub_id {
    select when wrangler subscription_added
      name re#(.*)#
      Id re#(.*)#
        setting(sub_name, sub_id)
    fired {
      ent:subs := ent:subs.defaultsTo({}).put(sub_name, sub_id)
    }
  }

  rule delete_vehicle {
    select when car unneeded_vehicle name re#(.*)# setting(name)
    pre {
      sub_id = get_subscription_by_name(name)
    }
    if sub_id then noop();
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Id": sub_id};
      raise wrangler event "child_deletion"
        attributes {"name": name};
      ent:subs := ent:subs.delete(name + "-sub")
    }
  }
}
