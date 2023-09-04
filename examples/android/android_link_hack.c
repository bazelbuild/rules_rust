// https://github.com/bazelbuild/rules_rust/issues/1271
extern void android_link_hack(void);

void call_link_hack(void) { android_link_hack(); }
