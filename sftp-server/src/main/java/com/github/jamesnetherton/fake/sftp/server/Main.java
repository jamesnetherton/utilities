package com.github.jamesnetherton.fake.sftp.server;

import java.io.IOException;
import java.util.Collections;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.sshd.server.SshServer;
import org.apache.sshd.server.keyprovider.SimpleGeneratorHostKeyProvider;
import org.apache.sshd.sftp.server.SftpSubsystemFactory;

public class Main {

    public static void main(String args[]) {
        String ftpUser = System.getenv("FTP_USER");
        String ftpPassword = System.getenv("FTP_PASSWORD");

        if (ftpUser == null) {
            System.err.println("Missing environment variable FTP_USER");
            System.exit(1);
        }

        if (ftpPassword == null) {
            System.err.println("Missing environment variable FTP_PASSWORD");
            System.exit(1);
        }

        SftpSubsystemFactory factory = new SftpSubsystemFactory.Builder().build();
        SshServer sshd = SshServer.setUpDefaultServer();
        sshd.setSubsystemFactories(Collections.singletonList(factory));
        sshd.setHost("0.0.0.0");
        sshd.setPort(2222);
        sshd.setKeyPairProvider(new SimpleGeneratorHostKeyProvider());
        sshd.setPasswordAuthenticator((username, password, session) -> username.equals(ftpUser) && password.equals(ftpPassword));

        ExecutorService executorService = Executors.newSingleThreadExecutor();
        executorService.submit(() -> {
            try {
                sshd.start();
                System.out.println("\u001B[31m===========================================\n");
                System.out.println("Test SFTP server. Not for production usage!");
                System.out.println("\n===========================================\u001B[0m\n\n");
                System.out.println("SFTP Server started on 0.0.0.0:2222");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                System.out.println("Stopping SFTP Server");
                sshd.stop();
            } catch (IOException e) {
                System.err.println("Error stopping SFTP server: " + e.getMessage());
            }
            System.out.println("SFTP Server Stopped");
            executorService.shutdown();
        }));
    }
}
