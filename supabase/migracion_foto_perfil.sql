-- Foto de perfil del usuario (URL pública en Storage bucket imagenes/perfiles/{id}.jpg)
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS foto_url text;
