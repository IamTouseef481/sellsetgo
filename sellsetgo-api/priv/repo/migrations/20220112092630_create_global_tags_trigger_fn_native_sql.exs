defmodule SellSetGoApi.Repo.Migrations.CreateGlobalTagsTriggerFnNativeSql do
  use Ecto.Migration

  def up do
    execute("""
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    """)

    execute("""
    CREATE OR REPLACE FUNCTION insert_global_tags() RETURNS trigger AS $global_tags_trigger$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO global_template_tags 
          (id, template_tags, user_id, inserted_at, updated_at) 
          VALUES (
          gen_random_uuid(), 
          array[
            jsonb_object('{{tag, about},{type, "text"},{value, ""}}'),
            jsonb_object('{{tag, payment},{type, "text"},{value, ""}}'),
            jsonb_object('{{tag, shipping},{type, "text"},{value, ""}}'),
            jsonb_object('{{tag, returns},{type, "text"},{value, ""}}'),
            jsonb_object('{{tag, contact},{type, "text"},{value, ""}}')
          ], 
          NEW.id, 
          now(), 
          now()
          );
          RETURN NEW;
        END IF;
      END;
    $global_tags_trigger$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER insert_default_global_tags
      AFTER INSERT ON users
      FOR EACH ROW
      EXECUTE PROCEDURE insert_global_tags();
    """)
  end

  def down do
    execute("""
    DROP TRIGGER IF EXISTS insert_default_global_tags ON users;
    """)

    execute("""
    DROP FUNCTION IF EXISTS insert_global_tags();
    """)

    execute("""
    DROP EXTENSION IF EXISTS "pgcrypto";
    """)
  end
end
