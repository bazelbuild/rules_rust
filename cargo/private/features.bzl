"""Feature helpers."""

def feature_enabled(ctx, feature_name, default = False):
    """Check if a feature is enabled.

    If the feature is explicitly enabled or disabled, return accordingly.

    In the case where the feature is not explicitly enabled or disabled, return the default value.

    Args:
        ctx: The context object.
        feature_name: The name of the feature.
        default: The default value to return if the feature is not explicitly enabled or disabled.

    Returns:
        Boolean defining whether the feature is enabled.
    """
    if feature_name in ctx.disabled_features:
        return False

    if feature_name in ctx.features:
        return True

    return default
