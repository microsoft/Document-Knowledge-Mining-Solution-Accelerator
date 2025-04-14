import React, { useState, useCallback, useEffect } from "react";
import { useDropzone } from "react-dropzone";
import {
  Button,
  Dialog,
  DialogTrigger,
  DialogSurface,
  DialogBody,
  DialogTitle,
  DialogContent,
  ProgressBar,
} from "@fluentui/react-components";
import {
  ArrowUpload24Regular,
  Document24Regular,
  DismissRegular,
  CheckmarkCircle24Regular,
  DismissCircle24Regular, CloudArrowUp24Regular, DocumentPdf32Regular
} from "@fluentui/react-icons";
import { Icon } from "@fluentui/react";
import { importDocuments } from "../../api/documentsService";
import { getFileTypeIconProps } from "@fluentui/react-file-type-icons";

const UploadDocumentsDialog = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [uploadingFiles, setUploadingFiles] = useState<
    { name: string; progress: number; status: string; errorMsg: string }[]
  >([]);
  const [isUploading, setIsUploading] = useState(false);
  const [isUploadBtnVisible, setIsUploadBtnVisible] = useState<boolean>(false);


  function toBoolean(value: unknown): boolean {
    return String(value).toLowerCase() === "true";
  }

  useEffect(() => {
    if (import.meta.env.VITE_ENABLE_UPLOAD_BUTTON != undefined){
        const flag = import.meta.env.VITE_ENABLE_UPLOAD_BUTTON;
      setIsUploadBtnVisible(toBoolean(flag))
    }
  }, [import.meta.env.VITE_ENABLE_UPLOAD_BUTTON])

  // Handle file drop and simulate upload
  const onDrop = useCallback(async (acceptedFiles: any[]) => {
    setIsUploading(true);
    const newFiles = acceptedFiles.map((file: { name: any; }) => ({
      name: file.name,
      progress: 0,
      status: "uploading",
      errorMsg: ""
    }));
    setUploadingFiles((prev) => [...prev, ...newFiles]);

    for (let i = 0; i < acceptedFiles.length; i++) {
      const file = acceptedFiles[i];
      const formData = new FormData();
      formData.append("file", file);

      try {
        // Simulate upload delay
        await new Promise((resolve) => setTimeout(resolve, 2000));
        await importDocuments(formData); // Replace with actual upload API

        // Update file status to success
        setUploadingFiles((prev) =>
          prev.map((f, index) =>
            index === prev.length - acceptedFiles.length + i
              ? { ...f, progress: 100, status: "success", errorMsg: "" }
              : f
          )
        );
      } catch (error: any) {
        const errorMessage = error.message.replace(/^Error:\s*/, ""); // Remove "Error: " prefix
        const parsedError = JSON.parse(errorMessage);

        // Update file status to error
        setUploadingFiles((prev) =>
          prev.map((f, index) =>
            index === prev.length - acceptedFiles.length + i
              ? { ...f, progress: 100, status: "error", errorMsg: parsedError.summary }
              : f
          )
        );
      }
    }
    setIsUploading(false);
  }, []);

  const { getRootProps, getInputProps, open } = useDropzone({
    onDrop,
    noClick: true,
    noKeyboard: true,
  });

  return (<>
    {isUploadBtnVisible == true ?
      <Dialog open={isOpen} onOpenChange={(event, data) => setIsOpen(data.open)}>
        <DialogTrigger>
          <Button icon={<ArrowUpload24Regular />} onClick={() => setIsOpen(true)}>
            Upload documents
          </Button>
        </DialogTrigger>
        <DialogSurface>
          <DialogBody>
            <DialogTitle>
              Upload Documents
              <Button
                icon={<DismissRegular />}
                appearance="subtle"
                onClick={() => setIsOpen(false)}
                style={{ position: "absolute", right: 20, top: 20 }}
              />
            </DialogTitle>

            <DialogContent>
              {isUploading ? (
                <div style={{ textAlign: "center", padding: "40px 0" }}>
                  <Icon
                    {...getFileTypeIconProps({ extension: "pdf", size: 32, imageFileType: "svg" })}
                  />
                  <p style={{ fontSize: "1.25rem" }}>Uploading documents...</p>
                </div>
              ) : (
                <div
                  {...getRootProps()}
                  style={{
                    border: "2px dashed #ccc",
                    borderRadius: "4px",
                    padding: "20px",
                    textAlign: "center",
                    marginBottom: "20px",
                  }}
                >
                  <input {...getInputProps()} />
                  <CloudArrowUp24Regular
                    style={{
                      fontSize: "48px",
                      color: "#551A8B",
                      marginBottom: "10px",
                    }}
                  />
                  <p>Drag and drop files</p>
                  <p>or</p>
                  <Button appearance="secondary" onClick={open}>
                    Browse files
                  </Button>
                </div>
              )}

              {/* Upload link section */}
              {/* <div style={{ marginTop: "20px" }}>
              <h3>Upload link</h3>
              <div style={{ display: "flex", alignItems: "center" }}>
                <input
                  type="text"
                  placeholder="Paste a link here"
                  style={{
                    flex: 1,
                    padding: "8px",
                    border: "1px solid #ccc",
                    borderRadius: "4px 0 0 4px",
                  }}
                />
                <Button
                  icon={<ArrowUpload24Regular />}
                  style={{
                    backgroundColor: "#551A8B",
                    color: "white",
                    borderRadius: "0 4px 4px 0",
                  }}
                />
              </div>
            </div> */}

              {/* File progress display */}
              {uploadingFiles.map((file, index) => (
                <div
                  key={index}
                  style={{
                    marginTop: "20px",
                    border: "1px solid #ccc",
                    borderRadius: "4px",
                    padding: "10px",
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center" }}>
                      <Icon  {...getFileTypeIconProps({ extension: "pdf", size: 32, imageFileType: "svg" })} />
                      <span>{file.name}</span>
                    </div>
                    {file.status === "success" && (
                      <CheckmarkCircle24Regular style={{ color: "green" }} />
                    )}
                    {file.status === "error" && (
                      <DismissCircle24Regular style={{ color: "red" }} />
                    )}
                  </div>
                  <ProgressBar value={file.progress} />
                  <span
                    style={{
                      color: file.status === "error" ? "red" : "inherit", // Apply red color only for error messages
                    }}>
                    {file.status === "uploading"
                      ? "Uploading..."
                      : file.status === "success"
                        ? "Upload complete"
                        : file.errorMsg}
                  </span>
                  <span>{ }</span>
                </div>
              ))}
            </DialogContent>
          </DialogBody>
        </DialogSurface>
      </Dialog> : <></>
    }
  </>
  )


};

export default UploadDocumentsDialog;
