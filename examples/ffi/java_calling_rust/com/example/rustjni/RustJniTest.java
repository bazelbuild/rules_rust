package com.example.rustjni;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.equalTo;

import org.junit.Test;

public class RustJniTest {
    @Test
    public void testCallsJniToRust() throws Exception {
        final String s = "hello";
        long result = RustStringLength.loadNativeLibrary().calculate_string_length_from_rust(s);
        assertThat(result, equalTo(5L));
    }
}
