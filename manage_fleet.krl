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
    shares vehicles, generate_report_via_functions, stop_report, get_last_5_reports
  }

  global {
    vehicles = function() {
      Subscriptions:established("Tx_role","vehicle")
    }

    get_vehicle_count = function() {
      ent:vehicles.length()
    }

    get_subscription_by_name = function(name)  {
      ent:subs{name + "-sub"}
    }

    get_last_5_reports = function() {
      len = ent:all_reports.length();
      (len < 5) =>
        ent:all_reports |
        ent:all_reports.slice(len - 5, len - 1)
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
    pre {
      report_id = random:uuid()
      attributes = event:attrs.put("report_id", report_id)
    }
    fired {
      raise explicit event "start_report"
        attributes attributes
          if (not ent:currently_reporting)
    }
  }

  rule start_report {
    select when explicit start_report
      foreach ent:vehicles setting(vehicle)
        pre {
          my_eci = meta:eci
          vehicle = wrangler:children(vehicle)[0].klog("vehicle: ")
          my_attrs = {}
            .put("report_id", event:attr("report_id"))
            .put("report_to_eci", my_eci)
            .put("vehicle_name", vehicle{"name"})
            .put("vehicle_id", vehicle{"id"})
        }
        event:send({ "eci" : vehicle{"eci"}, "domain" : "report", "type" : "get_trips", "attrs" : my_attrs })
        fired {
          ent:currently_reporting := true
        }
  }

  rule get_reported_trips {
    select when report reported_trips
    fired {
      vehicle_id = event:attr("vehicle_id").klog("reported vehicle id: ");
      vehicle_name = event:attr("vehicle_name").klog("reported vehicle name: ");
      trips = event:attr("trips").klog("reported trips: ");
      ent:current_count := ent:current_count.defaultsTo(0) + 1;
      vehicle_report = {}
        .put("name", vehicle_name)
        .put("trips", trips);

      ent:current_report := ent:current_report.defaultsTo({})
        .put(vehicle_id, vehicle_report);

      attributes = {}
        .put("report", ent:current_report)
        .put("reporting_count", ent:current_count)
        .put("vehicle_count", get_vehicle_count());

      raise explicit event "check_report"
        attributes attributes
    }
  }

  rule check_report {
    select when explicit check_report
    fired {
      raise explicit event "finalize_report"
        attributes {
          "reporting_count" : event:attr("reporting_count"),
          "vehicle_count" : get_vehicle_count(),
          "report" : event:attr("report")
        }
          if (event:attr("reporting_count") == get_vehicle_count())
    }
  }

  rule finalize_report {
    select when explicit finalize_report
    send_directive("report", event:attr("report"))
    fired {
      final_report = event:attr("report")
        .put("reporting_count", event:attr("reporting_count"))
        .put("vehicle_count", event:attr("vehicle_count"));
      ent:all_reports := ent:all_reports
        .defaultsTo([])
        .append(final_report);
      ent:currently_reporting := false;
      ent:current_report := {};
      ent:current_count := 0
    }
  }

  rule stop_report {
    select when report stop
    fired {
      ent:currently_reporting := false;
      ent:current_report := {};
      ent:current_count := 0
    }
  }
}
