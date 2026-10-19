/*-
 * #%L
 * heads-of-governments-db
 * %%
 * Copyright (C) 2026 Jinahya, Inc.
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */
package com.github.jinahya.headsofgovernments;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import ch.qos.logback.classic.encoder.PatternLayoutEncoder;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.ConsoleAppender;
import org.slf4j.LoggerFactory;

/**
 * Reconfigures Logback from a test, for a test that wants its output a certain way whatever
 * {@code logback-test.xml} says.
 */
final class _LoggingUtils {

    /** The pattern {@link #messageOnly()} sets: the message alone, one per line. */
    static final String MESSAGE_ONLY_PATTERN = "%msg%n";

    // -----------------------------------------------------------------------------------------------------------------

    /**
     * Replaces the appenders of the root logger with a single console appender that prints the message alone; the
     * root level is left as it is.
     */
    static void messageOnly() {
        final var context = (LoggerContext) LoggerFactory.getILoggerFactory();
        final var encoder = new PatternLayoutEncoder();
        encoder.setContext(context);
        encoder.setPattern(MESSAGE_ONLY_PATTERN);
        encoder.start();
        final var appender = new ConsoleAppender<ILoggingEvent>();
        appender.setContext(context);
        appender.setName("CONSOLE");
        appender.setEncoder(encoder);
        appender.start();
        final var root = context.getLogger(Logger.ROOT_LOGGER_NAME);
        root.detachAndStopAllAppenders();
        root.addAppender(appender);
    }

    // -----------------------------------------------------------------------------------------------------------------
    private _LoggingUtils() {
        throw new AssertionError("instantiation is not allowed");
    }
}
