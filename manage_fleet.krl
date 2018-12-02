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
    shares vehicles, generate_report_via_functions
  }

  global {
    vehicles = function() {
      Subscriptions:established("Tx_role","vehicle")
    }

    get_subscription_by_name = function(name)  {
      ent:subs{name + "-sub"}
    }

    generate_report_via_functions = function() {
      report = {};
      ent:vehicles.map(function(vehicle_name) {
        vehicle = wrangler:children(vehicle_name)[0].klog("here's the vehicle: ");
        vehicle_id = vehicle{"id"};
        base_url = "http://localhost:8080/sky/cloud/";
        vehicle_eci = vehicle{"eci"};
        trips_function = "/track_trips/trips";
        full_url = base_url + vehicle_eci + trips_function;
        response = {"trips" : http:get(full_url){"content"}.decode()}
          .put("vehicle_name", vehicle{"name"})
          .klog("test: ");
        vehicle_report = {}.put(vehicle_id, response);
        vehicle_report.klog("vehicle_report: ")
      })
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
    fired {
      ent:vehicles := ent:vehicles.defaultsTo([]).append([sub_name])
    }
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
      ent:subs := ent:subs.delete(name + "-sub");
      name_index = ent:vehicles.index(name);
      ent:vehicles := ent:vehicles.splice(name_index, 1)
    }
  }

  rule scatter_gather {
    select when report scatter_gather
      foreach ent:vehicles setting(vehicle)
        pre {
          vehicle_eci = wrangler:children(vehicle)[0]{"eci"}.klog("vehicle eci: ")
        }
        event:send({ "eci" : vehicle_eci, "domain" : "report", "type" : "get_trips" })
  }
}
