CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) DEFAULT 'user'
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    category VARCHAR(100) DEFAULT 'general'
);

-- Opcjonalnie: przykładowe dane startowe
INSERT INTO users (name, email, role) VALUES
    ('Admin User', 'admin@example.com', 'admin')
ON CONFLICT (email) DO NOTHING;

INSERT INTO products (name, price, category) VALUES
    ('Sample Product', 19.99, 'general')
ON CONFLICT DO NOTHING;