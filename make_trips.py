import requests
from random import randint
from itertools import repeat

vehicle_ecis = []

for vehicle in vehicle_ecis:
  num_of_trips = randint(1, 10)
  trips = []
  for i in repeat(None, num_of_trips):
    trips.append(str(randint(1,999)))

  for trip in trips:
    requests.post('http://localhost:8080/sky/event/' + vehicle + '/python_script/car/new_trip?mileage=' + trip)
