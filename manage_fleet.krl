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
                     "color": "#ffff00",
                     "rids": "track_trips" }
    }
  }
}
