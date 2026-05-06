package com.newsblur.util;

import static org.junit.Assert.assertEquals;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

public class LogFileSnapshotTest {

    @Rule
    public TemporaryFolder folder = new TemporaryFolder();

    @Test
    public void emailAttachmentKeepsNewestShortLinesEvenWhenSourceIsUnderByteLimit() throws Exception {
        File source = folder.newFile("logbuffer.txt");
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(source))) {
            for (int i = 0; i < 2500; i++) {
                writer.write("line-" + i);
                writer.newLine();
            }
        }

        File target = folder.newFile("logbuffer-email.txt");
        Log.writeLatestLinesForAttachment(source, target, 1000);

        List<String> lines = readLines(target);
        assertEquals(1000, lines.size());
        assertEquals("line-1500", lines.get(0));
        assertEquals("line-2499", lines.get(999));
    }

    private static List<String> readLines(File file) throws Exception {
        List<String> lines = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            for (String line = reader.readLine(); line != null; line = reader.readLine()) {
                lines.add(line);
            }
        }
        return lines;
    }
}
