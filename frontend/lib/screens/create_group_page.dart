import 'dart:async';

import 'package:flutter/material.dart';

import '../models/group_creation_draft.dart';
import '../models/location_suggestion.dart';
import '../services/location_repository.dart';
import '../theme/app_tokens.dart';
import '../widgets/primary_action_button.dart';
import 'group_created_page.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  static const routeName = '/create-group';

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _areaFocusNode = FocusNode();

  LocationSuggestion? _selectedLocation;
  int _peopleCount = 4;
  BudgetOption? _selectedBudget = BudgetOption.from2000To3000;
  bool _hasTriedSubmit = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _areaController.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _hasTriedSubmit = true);

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _areaFocusNode.requestFocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('エリアを入力するとグループを作成できます')),
        );
      return;
    }

    final selectedBudget = _selectedBudget;
    if (selectedBudget == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('予算を選んでください')));
      return;
    }

    setState(() => _isSubmitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(AppMotion.quick);
    if (!mounted) {
      return;
    }

    final draft = GroupCreationDraft.createMock(
      peopleCount: _peopleCount,
      area: _selectedLocation?.displayName ?? _areaController.text.trim(),
      budget: selectedBudget,
      locationId: _selectedLocation?.id,
    );

    await Navigator.of(
      context,
    ).pushNamed(GroupCreatedPage.routeName, arguments: draft);
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _selectBudget(BudgetOption budget) {
    setState(() => _selectedBudget = budget);
  }

  void _selectLocation(LocationSuggestion? location) {
    setState(() => _selectedLocation = location);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.large
        : AppSpacing.xLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('グループ作成')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.large,
            horizontalPadding,
            AppSpacing.large,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _CreateGroupForm(
                        formKey: _formKey,
                        areaController: _areaController,
                        areaFocusNode: _areaFocusNode,
                        hasTriedSubmit: _hasTriedSubmit,
                        peopleCount: _peopleCount,
                        selectedLocation: _selectedLocation,
                        selectedBudget: _selectedBudget,
                        onAreaSubmitted: _createGroup,
                        onLocationSelected: _selectLocation,
                        onDecreasePeople: _peopleCount > 2
                            ? () => setState(() => _peopleCount--)
                            : null,
                        onIncreasePeople: _peopleCount < 10
                            ? () => setState(() => _peopleCount++)
                            : null,
                        onBudgetSelected: _selectBudget,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.regular),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryActionButton(
                      label: 'グループを作成',
                      onPressed: _isSubmitting ? null : _createGroup,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupForm extends StatelessWidget {
  const _CreateGroupForm({
    required this.formKey,
    required this.areaController,
    required this.areaFocusNode,
    required this.hasTriedSubmit,
    required this.peopleCount,
    required this.selectedLocation,
    required this.selectedBudget,
    required this.onAreaSubmitted,
    required this.onLocationSelected,
    required this.onDecreasePeople,
    required this.onIncreasePeople,
    required this.onBudgetSelected,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController areaController;
  final FocusNode areaFocusNode;
  final bool hasTriedSubmit;
  final int peopleCount;
  final LocationSuggestion? selectedLocation;
  final BudgetOption? selectedBudget;
  final VoidCallback onAreaSubmitted;
  final ValueChanged<LocationSuggestion?> onLocationSelected;
  final VoidCallback? onDecreasePeople;
  final VoidCallback? onIncreasePeople;
  final ValueChanged<BudgetOption> onBudgetSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: formKey,
      autovalidateMode: hasTriedSubmit
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今夜の集合を\nつくろう。', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.regular),
          Text(
            '人数、場所、予算。決まったらすぐ招待できます。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _FormSection(
            step: '01',
            title: '何人で行く？',
            child: _PeopleCounter(
              peopleCount: peopleCount,
              onDecrease: onDecreasePeople,
              onIncrease: onIncreasePeople,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _FormSection(
            step: '02',
            title: 'どのあたり？',
            child: _LocationSearchField(
              controller: areaController,
              focusNode: areaFocusNode,
              selectedLocation: selectedLocation,
              onSubmitted: onAreaSubmitted,
              onSelected: onLocationSelected,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _FormSection(
            step: '03',
            title: '予算はどれくらい？',
            child: Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: BudgetOption.values.map((budget) {
                return _BudgetChoiceChip(
                  label: budget.label,
                  selected: selectedBudget == budget,
                  onSelected: (_) => onBudgetSelected(budget),
                );
              }).toList(),
            ),
          ),
          if (hasTriedSubmit && selectedBudget == null) ...[
            const SizedBox(height: AppSpacing.regular),
            Text(
              '希望の予算を選んでください',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
        ],
      ),
    );
  }
}

class _LocationSearchField extends StatefulWidget {
  const _LocationSearchField({
    required this.controller,
    required this.focusNode,
    required this.selectedLocation,
    required this.onSubmitted,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LocationSuggestion? selectedLocation;
  final VoidCallback onSubmitted;
  final ValueChanged<LocationSuggestion?> onSelected;

  @override
  State<_LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<_LocationSearchField> {
  final _repository = LocationRepositoryProvider.instance;

  Timer? _debounceTimer;
  List<LocationSuggestion> _suggestions = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _requestSerial = 0;
  bool _isApplyingSelection = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_isApplyingSelection) {
      return;
    }

    if (widget.selectedLocation != null) {
      widget.onSelected(null);
    }

    final query = widget.controller.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _repository.searchLocations(query);
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } on LocationSearchException catch (error) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _isLoading = false;
        _errorMessage = '地点候補を取得できませんでした';
      });
    }
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    _debounceTimer?.cancel();
    _isApplyingSelection = true;
    widget.controller.text = suggestion.displayName;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    _isApplyingSelection = false;
    widget.onSelected(suggestion);
    setState(() {
      _suggestions = const [];
      _isLoading = false;
      _errorMessage = null;
    });
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasPanel =
        _isLoading || _errorMessage != null || _suggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmitted(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
            hintText: '北千住・足立区・新宿',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '行きたい地点を入力してください';
            }
            if (widget.selectedLocation == null) {
              return '候補から地点を選んでください';
            }
            return null;
          },
        ),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: hasPanel
              ? Padding(
                  key: const ValueKey('location-suggestion-panel'),
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: _buildPanel(context),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty-location-panel')),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.medium),
        child: LinearProgressIndicator(),
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Text(
          errorMessage,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: colors.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: Icon(
            suggestion.type == LocationSuggestionType.station
                ? Icons.train_rounded
                : Icons.place_outlined,
          ),
          title: Text(suggestion.name),
          subtitle: Text(suggestion.supportingText),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
}

class _BudgetChoiceChip extends StatefulWidget {
  const _BudgetChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  State<_BudgetChoiceChip> createState() => _BudgetChoiceChipState();
}

class _BudgetChoiceChipState extends State<_BudgetChoiceChip> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmphasized = widget.selected || _isHovered || _isFocused;

    return Focus(
      onFocusChange: (value) => setState(() => _isFocused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: isEmphasized ? 1.02 : 1,
          duration: AppMotion.quick,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              boxShadow: widget.selected
                  ? AppShadows.elevatedAction(colors.primary)
                  : const [],
            ),
            child: ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.micro,
                  vertical: AppSpacing.small,
                ),
                child: Text(widget.label),
              ),
              selected: widget.selected,
              onSelected: widget.onSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                step,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.regular),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: AppSpacing.medium),
        child,
      ],
    );
  }
}

class _PeopleCounter extends StatelessWidget {
  const _PeopleCounter({
    required this.peopleCount,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int peopleCount;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '人数を減らす',
            onPressed: onDecrease,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.secondaryButtonHeight),
            ),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '$peopleCount人',
              excludeSemantics: true,
              child: Text(
                '$peopleCount人',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: '人数を増やす',
            onPressed: onIncrease,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.secondaryButtonHeight),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
