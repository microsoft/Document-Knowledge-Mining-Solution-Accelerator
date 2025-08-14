export const httpClient = {
    get,
    post,
    put,
    delete: _delete,
    download,
    patch,
    upload,
};

async function get<T>(path: string): Promise<T> {
    const response = await fetch(path, { method: "GET" });
    return response.json();
}

async function post<T, U>(path: string, body?: T): Promise<U> {
    const response = await fetch(path, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: body ? JSON.stringify(body) : undefined
    });
    return response.json();
}

async function put<T, U>(path: string, body: T): Promise<U> {
    const response = await fetch(path, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
    });
    return response.json();
}

async function _delete<T>(path: string): Promise<T> {
    const response = await fetch(path, { method: "DELETE" });
    return response.json();
}

async function download(path: string, fileName: string): Promise<void> {
    const response = await fetch(path);
    const blob = await response.blob();
    
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", fileName);
    
    document.body.appendChild(link);
    link.click();
    link.parentNode?.removeChild(link);
}

async function patch<T, U>(path: string, body: T): Promise<U> {
    const response = await fetch(path, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
    });
    return response.json();
}

async function upload<T>(path: string, formData: FormData): Promise<T> {
    const response = await fetch(path, {
        method: "POST",
        body: formData
    });
    return response.json();
}
