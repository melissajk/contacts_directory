CREATE TABLE contacts (
  id serial PRIMARY KEY,
  name text NOT NULL,
  address text,
  email text,
  category text NOT NULL,
  phone_number char(10) NOT NULL CHECK (phone_number ~ '^\d{10}$')
);

INSERT INTO contacts (name, address, email, category, phone_number)
VALUES ('Gene C', 'Phoenix, AZ', 'genec@email.com', 'friends', '9135555284' ),
('Jill Thomas', '673 Main St Lee''s Summit MO 64063', 'puppylove74@email.com', 'friends', '8165251674'),
('Cara Ellerson', '903 Manner St Kansas City, MO 64062', 'caraell@email.com', 'family', '8165558652'),
('Linus Moore', '502 Monroe Blvd Overland Park, KS 66207', 'linusmoore@email.com', 'business', '9136421810');
