package com.github.jamesnetherton.redeploy.perpetual;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.Socket;
import java.net.UnknownHostException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import org.jboss.as.cli.impl.CLIModelControllerClient;
import org.jboss.as.controller.client.ModelControllerClient;
import org.jboss.as.controller.client.Operation;
import org.jboss.as.controller.client.helpers.ClientConstants;
import org.jboss.as.controller.client.helpers.Operations;
import org.jboss.dmr.ModelNode;

import static org.jboss.as.controller.client.helpers.ClientConstants.CONTENT;
import static org.jboss.as.controller.client.helpers.ClientConstants.DEPLOYMENT;
import static org.jboss.as.controller.client.helpers.ClientConstants.DEPLOYMENT_UNDEPLOY_OPERATION;
import static org.jboss.as.controller.client.helpers.ClientConstants.PATH;
import static org.jboss.as.controller.client.helpers.ClientConstants.RUNTIME_NAME;
import static org.jboss.as.controller.client.helpers.Operations.createAddOperation;
import static org.jboss.as.controller.client.helpers.Operations.createOperation;
import static org.jboss.as.controller.client.helpers.Operations.createRemoveOperation;

public class Utils {

    private static final int BUFFER_SIZE = 4096;
    private static final String ARCHIVE = "archive";
    private static final String BYTES = "bytes";

    public static String createGavCordinates(String... gavCoordinates) {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < gavCoordinates.length; i++) {
            builder.append(gavCoordinates[i]);
            if (i + 1 < gavCoordinates.length) {
                builder.append(":");
            }
        }
        return builder.toString();
    }

    public static void unzipFile(String zipFilePath, String destDirectory) throws IOException {
        File destDir = new File(destDirectory);
        if (!destDir.exists()) {
            destDir.mkdir();
        }
        ZipInputStream zipIn = new ZipInputStream(new FileInputStream(zipFilePath));
        ZipEntry entry = zipIn.getNextEntry();
        // iterates over entries in the zip file
        while (entry != null) {
            String filePath = destDirectory + File.separator + entry.getName();
            if (!entry.isDirectory()) {
                // if the entry is a file, extracts it
                extractFile(zipIn, filePath);
            } else {
                // if the entry is a directory, make the directory
                File dir = new File(filePath);
                dir.mkdir();
            }
            zipIn.closeEntry();
            entry = zipIn.getNextEntry();
        }
        zipIn.close();
    }

    public static void deployApplication(String path) {
        ModelControllerClient modelControllerClient = null;

        try {
            modelControllerClient = CLIModelControllerClient.Factory.create("localhost", 9999);

            String runtimeName = path.substring(path.lastIndexOf('/') + 1, path.length());

            final ModelNode address = createAddress(DEPLOYMENT, runtimeName);
            final ModelNode addOperation = createAddOperation(address);
            if (runtimeName != null) {
                addOperation.get(RUNTIME_NAME).set(runtimeName);
            }
            addContent(Paths.get(path), addOperation, Files.isDirectory(Paths.get(path)));
            Operation op = Operations.CompositeOperationBuilder.create()
                .addStep(addOperation)
                .addStep(createOperation(ClientConstants.DEPLOYMENT_DEPLOY_OPERATION, address))
                .build();

            consoleOutput("Deploying: " + runtimeName);

            ModelNode result = modelControllerClient.execute(op);

            if (Operations.isSuccessfulOutcome(result)) {
                consoleOutput("Deployed: " + runtimeName);
            } else {
                consoleOutput("Failed Deploying: " + runtimeName + ". " + Operations.getFailureDescription(result).asString());
            }
        } catch (UnknownHostException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (modelControllerClient != null) {
                try {
                    modelControllerClient.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    public static void undeployApplication(String path) {
        ModelControllerClient modelControllerClient = null;
        try {
            modelControllerClient = CLIModelControllerClient.Factory.create("localhost", 9999);

            String runtimeName = path.substring(path.lastIndexOf('/') + 1, path.length());

            final Operations.CompositeOperationBuilder builder = Operations.CompositeOperationBuilder.create();
            final ModelNode address = createAddress(DEPLOYMENT, runtimeName);
            builder.addStep(createOperation(DEPLOYMENT_UNDEPLOY_OPERATION, address)).addStep(createRemoveOperation(address));
            Operation op = builder.build();

            consoleOutput("Undeploying: " + runtimeName);

            ModelNode result = modelControllerClient.execute(op);
            modelControllerClient.close();
            if (Operations.isSuccessfulOutcome(result)) {
                consoleOutput("Undeployed: " + runtimeName);
            } else {
                consoleOutput("Failed undeploying: " + runtimeName + ". " + Operations.getFailureDescription(result).asString());
            }
        } catch (UnknownHostException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (modelControllerClient != null) {
                try {
                    modelControllerClient.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    public static void redeployApplication(String path) {
        consoleOutput("Redeploying application: " + path);
        undeployApplication(path);
        deployApplication(path);
    }

    public static boolean isServerRunning() {
        Socket socket = null;
        try {
            socket = new Socket("localhost", 9999);
            if (socket.isConnected()) {
                socket.close();
            } else {
                return false;
            }
        } catch (IOException e) {
            return false;
        }

        ModelControllerClient modelControllerClient = null;
        try {
            modelControllerClient = CLIModelControllerClient.Factory.create("localhost", 9999);
            final ModelNode response = modelControllerClient.execute((Operations.createReadAttributeOperation(new ModelNode().setEmptyList(), "server-state")));
            if (Operations.isSuccessfulOutcome(response)) {
                final String state = Operations.readResult(response).asString();
                return !ClientConstants.CONTROLLER_PROCESS_STATE_STARTING.equals(state) && !ClientConstants.CONTROLLER_PROCESS_STATE_STOPPING.equals(state);
            }
        } catch (UnknownHostException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (modelControllerClient != null) {
                try {
                    modelControllerClient.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return false;
    }

    public static void consoleOutput(String output) {
        System.out.println("==============> " + output);
    }

    public static boolean isWindows() {
        return System.getProperty("os.name").toLowerCase(Locale.US).contains("windows");
    }

    public static String getUniqueFileSuffix() {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("ddmmyyyyHHmm");
        return LocalDateTime.now().format(formatter);
    }

    private static ModelNode createAddress(final String key, final String name) {
        final ModelNode address = new ModelNode().setEmptyList();
        address.add(key, name);
        return address;
    }

    private static void addContent(final Path deployment, final ModelNode op, final boolean unmanaged) throws IOException {
        final ModelNode contentNode = op.get(CONTENT);
        final ModelNode contentItem = contentNode.get(0);
        if (unmanaged) {
            contentItem.get(PATH).set(deployment.toString());
            contentItem.get(ARCHIVE).set(!Files.isDirectory(deployment));
        } else {
            contentItem.get(BYTES).set(Files.readAllBytes(deployment));
        }
    }

    private static void extractFile(ZipInputStream zipIn, String filePath) throws IOException {
        BufferedOutputStream bos = new BufferedOutputStream(new FileOutputStream(filePath));
        byte[] bytesIn = new byte[BUFFER_SIZE];
        int read = 0;
        while ((read = zipIn.read(bytesIn)) != -1) {
            bos.write(bytesIn, 0, read);
        }
        bos.close();
    }
}
