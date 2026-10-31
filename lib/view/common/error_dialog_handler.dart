import "package:flutter/cupertino.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";

//TODO: 微妙な方法

class SpecifiedException implements Exception {
  final String message;
  SpecifiedException(this.message);
}

extension FutureExtension<T> on Future<T> {
  @Deprecated("use `dialogStateNotifier`")
  Future<T?> expectFailure(BuildContext context) async {
    try {
      return await this;
    } catch (error) {
      if (context.mounted) {
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(errorEventProvider.notifier).state = (
          error,
          context,
        );
      }
      return null;
    }
  }
}

extension FutureFunctionExtension<T> on Future<T> Function() {
  @Deprecated("use `dialogStateNotifier`")
  Future<T?> Function() expectFailure(BuildContext context) {
    return () => this.call().expectFailure(context);
  }
}
