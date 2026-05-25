// supabase/functions/delete-user/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2';

// Helper function to recursively get all file paths in a folder
async function getAllFilePaths(supabase: any, bucket: string, folderPath: string): Promise<string[]> {
  const { data: list, error } = await supabase.storage.from(bucket).list(folderPath);

  if (error || !list || list.length === 0) {
    return [];
  }

  let filePaths: string[] = [];

  for (const item of list) {
    // Construct the full path for the item
    const itemPath = `${folderPath}/${item.name}`;

    // In Supabase Storage, files have an `id`, folders do not.
    if (item.id) {
      filePaths.push(itemPath);
    } else {
      // If it's a folder, recursively fetch its contents
      const subFiles = await getAllFilePaths(supabase, bucket, itemPath);
      filePaths = [...filePaths, ...subFiles];
    }
  }

  return filePaths;
}

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

    // 1. Get all file paths inside the user's folder
    const filesToDelete = await getAllFilePaths(supabase, 'entry-photos', user.id);

    // 2. Delete the files (if any exist)
    if (filesToDelete.length > 0) {
      // Note: Supabase allows a maximum of 100 files per remove() call.
      // If a user could have >100 photos, you'd need to chunk this array.
      const { error: deleteStorageError } = await supabase.storage
        .from('entry-photos')
        .remove(filesToDelete);

      if (deleteStorageError) {
        console.error('Storage delete error:', deleteStorageError);
        // Decide if you want to block user deletion if storage fails
      }
    }

    // 3. Delete the user account
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