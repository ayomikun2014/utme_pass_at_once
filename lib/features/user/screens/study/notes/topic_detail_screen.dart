import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/features/user/models/study_notes_model.dart';

class TopicDetailScreen extends StatelessWidget {
  final StudyTopicModel topic;
  final String subjectName;

  const TopicDetailScreen({
    super.key,
    required this.topic,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: topic.title,
                subtitle: subjectName.toUpperCase(),
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final block = topic.content[index];
                      return _buildContentBlock(context, block, theme, isDark);
                    },
                    childCount: topic.content.length,
                  ),
                ),
              ),
              if (topic.sourcePage > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Source: Page ${topic.sourcePage}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentBlock(
      BuildContext context,
      StudyContentBlockModel block,
      ThemeData theme,
      bool isDark,
      ) {
    switch (block.type) {
      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            block.text ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.7,
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        );

      case 'bullet':
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (block.items ?? []).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium custom bullet point
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'latex':
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                block.value ?? '',
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  // Force text color so it doesn't render black in dark mode
                  color: theme.colorScheme.onSurface,
                ),
                onErrorFallback: (err) => Text(
                  block.value ?? '',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        );

      case 'table':
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              dataRowColor: WidgetStatePropertyAll(Colors.transparent),
              dividerThickness: 0.5,
              columns: (block.headers ?? [])
                  .map((h) => DataColumn(
                label: Text(
                  h.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ))
                  .toList(),
              rows: (block.rows ?? [])
                  .map((row) => DataRow(
                cells: row
                    .map((cell) => DataCell(
                  Text(
                    cell,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ))
                    .toList(),
              ))
                  .toList(),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}