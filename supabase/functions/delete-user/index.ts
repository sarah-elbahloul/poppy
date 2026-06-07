// ─────────────────────────────────────────────────────────────
//  POPPY — Edge Function: delete-user
//  Location: supabase/functions/delete-user/index.ts
// ─────────────────────────────────────────────────────────────

import { createClient } from 'npm:@supabase/supabase-js@2';

/**
 * Recursively retrieves all file paths within a specific storage folder.
 */
async function getAllFilePaths(supabase: any, bucket: string, folderPath: string): Promise<string[]> {
  const { data: list, error } = await supabase.storage.from(bucket).list(folderPath);

  if (error || !list || list.length === 0) {
    return [];
  }

  let filePaths: string[] = [];

  for (const item of list) {
    const itemPath = `${folderPath}/${item.name}`;

    // In Supabase Storage, files have an `id`, folders do not.
    if (item.id) {
      filePaths.push(itemPath);
    } else {
      const subFiles = await getAllFilePaths(supabase, bucket, itemPath);
      filePaths = [...filePaths, ...subFiles];
    }
  }

  return filePaths;
}

/**
 * Main function handler.
 * 
 * 1. Authenticates the user via the provided Bearer token.
 * 2. Deletes all photos associated with the user from Supabase Storage.
 * 3. Deletes the user account from Supabase Auth.
 */
Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const authHeader = req.headers.get('Authorization')!;
    const token = authHeader.replace('Bearer ', '');

    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (!user || authError) {
      return new Response('Unauthorized', { status: 401 });
    }

    // 1. Cleanup storage files.
    const filesToDelete = await getAllFilePaths(supabase, 'entry-photos', user.id);

    if (filesToDelete.length > 0) {
      const { error: deleteStorageError } = await supabase.storage
        .from('entry-photos')
        .remove(filesToDelete);

      if (deleteStorageError) {
        console.error('Storage delete error:', deleteStorageError);
      }
    }

    // 2. Delete the auth account.
    await supabase.auth.admin.deleteUser(user.id);

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Delete user error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
});
