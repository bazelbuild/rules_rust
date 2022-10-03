package com.example.androidapp;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

public class AndroidMain extends Activity {
  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.android_main);

    Log.v("Bazel", "Android app launched");
    System.loadLibrary("android_app"); // 'android_app' is the name of the native library in this example
    Log.v("Bazel", "Value from rust: " + JniShim.getValue());

    final TextView helloTextView = (TextView) findViewById(R.id.text_view);
    helloTextView.setText("Value from rust: " + JniShim.getValue());
  }
}
