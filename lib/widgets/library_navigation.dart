import 'package:flutter/material.dart';

class LibraryNavigation extends StatelessWidget implements PreferredSizeWidget {
  final bool collections;
  final VoidCallback onLibrary, onCollections;
  const LibraryNavigation({
    super.key,
    required this.collections,
    required this.onLibrary,
    required this.onCollections,
  });
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    child: Row(
      children: [
        _tab(
          context,
          'Library',
          Icons.auto_stories_outlined,
          !collections,
          onLibrary,
        ),
        const SizedBox(width: 12),
        _tab(
          context,
          'Collections',
          Icons.collections_bookmark_outlined,
          collections,
          onCollections,
        ),
      ],
    ),
  );
  Widget _tab(
    BuildContext context,
    String text,
    IconData icon,
    bool selected,
    VoidCallback action,
  ) => Expanded(
    child: Semantics(
      selected: selected,
      child: TextButton.icon(
        onPressed: action,
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(text),
      ),
    ),
  );
}
