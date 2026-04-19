-- Rydinex PostgreSQL + PostGIS schema
-- Safe to run on a fresh database

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

---------------------------------------------------------
-- USERS TABLE
---------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    role VARCHAR(20) CHECK (role IN ('rider', 'driver', 'admin')) NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

---------------------------------------------------------
-- VEHICLES TABLE
---------------------------------------------------------
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT CHECK (year >= 1990),
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (driver_id) REFERENCES users(id)
);

---------------------------------------------------------
-- DRIVERS TABLE
---------------------------------------------------------
CREATE TABLE drivers (
    id UUID PRIMARY KEY,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    vehicle_id UUID,
    rating FLOAT DEFAULT 5.0,
    FOREIGN KEY (id) REFERENCES users(id),
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id)
);

---------------------------------------------------------
-- RIDE REQUESTS TABLE
---------------------------------------------------------
CREATE TABLE ride_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID NOT NULL,
    pickup_location GEOGRAPHY(Point, 4326) NOT NULL,
    destination_location GEOGRAPHY(Point, 4326) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('pending', 'matched', 'expired')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (rider_id) REFERENCES users(id)
);

---------------------------------------------------------
-- RIDES TABLE
---------------------------------------------------------
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID NOT NULL,
    driver_id UUID,
    start_location GEOGRAPHY(Point, 4326),
    end_location GEOGRAPHY(Point, 4326),
    status VARCHAR(20) CHECK (status IN ('requested', 'accepted', 'in_progress', 'completed', 'cancelled')) DEFAULT 'requested',
    fare_estimate NUMERIC(10,2),
    fare_final NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (rider_id) REFERENCES users(id),
    FOREIGN KEY (driver_id) REFERENCES users(id)
);

---------------------------------------------------------
-- PAYMENTS TABLE
---------------------------------------------------------
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    method VARCHAR(20) CHECK (method IN ('card', 'cash', 'wallet')) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('pending', 'paid', 'failed')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (ride_id) REFERENCES rides(id)
);

---------------------------------------------------------
-- DRIVER LOCATION (REAL-TIME)
---------------------------------------------------------
CREATE TABLE driver_locations (
    driver_id UUID PRIMARY KEY,
    location GEOGRAPHY(Point, 4326) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (driver_id) REFERENCES users(id)
);

---------------------------------------------------------
-- RATINGS TABLE
---------------------------------------------------------
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    FOREIGN KEY (ride_id) REFERENCES rides(id)
);
