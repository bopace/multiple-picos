ruleset trip_store {
  meta {
    name "Trip Store"
    description <<
Trip Store ruleset for lab 6 - CS 462
>>
    author "Bo Pace"
    logging on
    provides trips, long_trips, short_trips
    shares trips, long_trips, short_trips
  }

  global {
    trips = function() {
      ent:all_trips
    }

    long_trips = function() {
      ent:long_trips
    }

    short_trips = function() {
      ent:all_trips.difference(ent:long_trips)
    }
  }

  rule collect_trips {
    select when explicit trip_processed mileage re#(.*)# timestamp re#(.*)# setting(m, timestamp)
    fired {
      ent:all_trips := ent:all_trips.defaultsTo([]).append({"mileage": m, "timestamp": timestamp}).klog("all trips so far: ")
    }
  }

  rule collect_long_trips {
    select when explicit found_long_trip mileage re#(.*)# timestamp re#(.*)# setting(m, timestamp)
    fired {
      ent:long_trips := ent:long_trips.defaultsTo([]).append({"mileage": m, "timestamp": timestamp}).klog("all long trips so far: ")
    }
  }

  rule clear_trips {
    select when car trip_reset
    fired {
      ent:all_trips := [].klog("all_trips cleared");
      ent:long_trips := [].klog("long_trips cleared");
    }
  }
}
