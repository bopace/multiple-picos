ruleset track_trips {
  meta {
    name "Track Trips"
    description <<
Track Trips ruleset for lab 6 - CS 462
>>
    author "Bo Pace"
    logging on
    use module trip_store
    shares trips
  }

  global {
    long_trip = 99

    trips = function() {
      trip_store:trips()
    }
  }

  rule process_trip {
    select when car new_trip mileage re#([-+]?[0-9]\d*(\.\d+)?)# setting(m)
    send_directive("trip", {"length":m})
    fired {
      timestamp = {"timestamp": time:now()};
      raise explicit event "trip_processed"
        attributes event:attrs.put(timestamp)
    }
  }

  rule find_long_trips {
    select when explicit trip_processed
    fired {
      raise explicit event "found_long_trip"
        attributes event:attrs
          if (event:attr("mileage") > long_trip)
    }
  }

  rule autoAccept {
    select when wrangler inbound_pending_subscription_added
    pre{
      attributes = event:attrs
    }
    always{
      raise wrangler event "pending_subscription_approval"
          attributes attributes;
    }
  }

  rule report_trips {
    select when report get_trips
    pre {
      vehicle_name = event:attr("vehicle_name").klog("track_trips vehicle name: ")
      vehicle_id = event:attr("vehicle_id").klog("track_trips vehicle id: ")
      trips_to_report = trips().klog("trips!!!!!!!!!! ")
      fleet_eci = event:attr("report_to_eci")
      my_attrs = {}
        .put("report_id", event:attr("report_id"))
        .put("vehicle_name", event:attr("vehicle_name"))
        .put("vehicle_id", event:attr("vehicle_id"))
        .put("trips", trips_to_report)
    }
    event:send({ "eci" : fleet_eci, "domain" : "report", "type" : "reported_trips", "attrs" : my_attrs })
  }
}
