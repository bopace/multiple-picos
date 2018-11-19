ruleset manage_fleet {
  meta {
    name "Manage Fleet"
    description <<
Manage Fleet ruleset for lab 7 - CS 462
>>
    author "Bo Pace"
    logging on
    use module io.picolabs.wrangler alias wrangler
  }

  rule create_vehicle {
    select when car new_vehicle name re#(.*)# setting(vehicle_name)
    fired {
      raise wrangler event "child_creation"
        attributes { "name": vehicle_name,
                     "color": "#ffb347",
                     "rids": "track_trips" }
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
                  "Rx_role": "fleet",
                  "Tx_role": "vehicle",
                  "channel_type": "subscription",
                  "wellKnown_Tx": vehicle_eci } } )
  }
}
