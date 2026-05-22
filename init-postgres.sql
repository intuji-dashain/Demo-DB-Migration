-- Create extension for standard UUIDs (if fallback generation is required)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Mock users table to satisfy foreign key constraint
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL
);

-- Destination table matching your exact Laravel Blueprint definition
CREATE TABLE IF NOT EXISTS referral_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Handled natively or by script
    name VARCHAR(255) UNIQUE NOT NULL,
    description VARCHAR(255) NULL,
    display_order SMALLINT DEFAULT 1 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creator_user_id UUID NULL,
    CONSTRAINT fk_creator_user FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE SET NULL
);