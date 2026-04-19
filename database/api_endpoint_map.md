# Rydinex API Endpoint Map (Postgres Function Backed)

This map links REST endpoints to SQL functions in database/postgres_button_actions.sql and pricing files.

## Auth and Account

- POST /auth/register
  - SQL: create_account(full_name, email, phone, role, password_hash)
  - Returns: user_id

- POST /auth/login
  - SQL: login_user(email, password_hash, session_minutes)
  - Returns: user_id, role, session_token, expires_at

- POST /auth/logout
  - SQL: logout_user(session_token)
  - Returns: boolean

- PATCH /users/{userId}
  - SQL: edit_profile(user_id, full_name, email, phone)
  - Returns: boolean

- PATCH /users/{userId}/password
  - SQL: change_password(user_id, old_password_hash, new_password_hash)
  - Returns: boolean

- DELETE /users/{userId}
  - SQL: delete_account(user_id)
  - Returns: boolean

## Driver Onboarding and Verification

- POST /drivers/become
  - SQL: become_driver(user_id, license_number)
  - Returns: boolean

- POST /drivers/{driverId}/documents
  - SQL: upload_driver_document(driver_id, doc_type, file_url)
  - Returns: document_id

- PATCH /drivers/{driverId}/vehicle
  - SQL: update_driver_vehicle_info(driver_id, vehicle_id)
  - Returns: boolean

- GET /drivers/{driverId}/rating
  - SQL: view_driver_rating(driver_id)
  - Returns: driver_id, current_rating

## Vehicle Management

- POST /vehicles
  - SQL: add_vehicle(driver_id, make, model, year, plate_number, color, photo_url)
  - Returns: vehicle_id

- PATCH /vehicles/{vehicleId}
  - SQL: edit_vehicle(vehicle_id, make, model, year, plate_number, color, photo_url)
  - Returns: boolean

- DELETE /vehicles/{vehicleId}
  - SQL: remove_vehicle(vehicle_id)
  - Returns: boolean

## Ride Requests

- POST /ride-requests
  - SQL: request_ride(rider_id, pickup_lon, pickup_lat, dest_lon, dest_lat)
  - Returns: request_id

- PATCH /ride-requests/{requestId}/pickup
  - SQL: set_pickup_location(request_id, lon, lat)
  - Returns: boolean

- PATCH /ride-requests/{requestId}/destination
  - SQL: set_destination_location(request_id, lon, lat)
  - Returns: boolean

- PATCH /ride-requests/{requestId}/cancel
  - SQL: cancel_request(request_id)
  - Returns: boolean

## Ride Lifecycle

- POST /rides/accept
  - SQL: accept_ride(request_id, driver_id)
  - Returns: ride_id

- POST /rides/reject
  - SQL: reject_ride(request_id)
  - Returns: boolean

- POST /rides/{rideId}/start
  - SQL: start_ride(ride_id)
  - Returns: boolean

- POST /rides/{rideId}/end
  - SQL: end_ride(ride_id, fare_final)
  - Returns: boolean

- POST /rides/{rideId}/cancel
  - SQL: cancel_ride(ride_id)
  - Returns: boolean

- POST /rides/{rideId}/message
  - SQL: send_ride_message(ride_id, sender_id, message)
  - Returns: message_id

- POST /rides/{rideId}/share
  - SQL: share_trip(ride_id, shared_with)
  - Returns: share_token

## Payments

- POST /payments/methods
  - SQL: add_payment_method(user_id, method_type, provider_token, last4, make_default)
  - Returns: method_id

- PATCH /payments/methods/select
  - SQL: select_payment_method(user_id, method_id)
  - Returns: boolean

- POST /payments/promo/apply
  - SQL: apply_promo_code(amount, code)
  - Returns: discounted_amount

- POST /payments/pay-now
  - SQL: pay_now(ride_id, amount, method, status)
  - Returns: payment_id

## Real-Time Driver Tracking

- POST /drivers/{driverId}/online
  - SQL: go_online(driver_id, lon, lat)
  - Returns: boolean

- POST /drivers/{driverId}/offline
  - SQL: go_offline(driver_id)
  - Returns: boolean

## Ratings and Reviews

- POST /ratings
  - SQL: submit_rating(ride_id, rating, comment, rater_user_id, rated_user_id, rated_role)
  - Returns: rating_id

- GET /users/{userId}/reviews
  - SQL: review_history(user_id)
  - Returns: list of ratings

## Pricing and Matching

- GET /ride-requests/{requestId}/distance
  - SQL: request_distance_meters(request_id)

- GET /ride-requests/{requestId}/distance-km
  - SQL: request_distance_km(request_id)

- GET /ride-requests/{requestId}/fare-estimate
  - SQL: estimated_fare(request_id, duration_min, base_fare, per_km_rate, per_min_rate)

- GET /ride-requests/{requestId}/quote
  - SQL: quote_request_by_market(request_id, market_code, weather, override_base, override_per_km, override_per_min, override_avg_speed_kmh)

- GET /ride-requests/{requestId}/match-top
  - SQL: match_quote_top_drivers(request_id, market_code, weather, top_n, avg_driver_speed_kmh)

## Minimal JSON Contracts

- Login request
  - { "email": "standard@rydinex.com", "password": "password" }

- Ride request create
  - { "riderId": "uuid", "pickup": {"lon": -87.6298, "lat": 41.8781}, "destination": {"lon": -87.9073, "lat": 41.9742} }

- Go online
  - { "driverId": "uuid", "lon": -87.6354, "lat": 41.8881 }

- Match + quote
  - query params: market=chicago&weather=rain&top=3

## Recommended Route Order for Implementation

1. Auth and account
2. Ride request and lifecycle
3. Tracking and nearest-driver matching
4. Payments
5. Ratings and review history
