import React from "react";

export function AzureIcon({ className }: { className?: string }): JSX.Element {
    return (
        <svg className={className} fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path
                fillRule="evenodd"
                clipRule="evenodd"
                d="M8.252 0h7.53a1.713 1.713 0 0 1 1.623 1.166L23.91 20.44a1.712 1.712 0 0 1-1.623 2.26h-7.342v-.006a1.76 1.76 0 0 1-.153.007h-.028c-.368 0-.727-.119-1.022-.338l-4.785-3.555-.921 2.727a1.713 1.713 0 0 1-1.623 1.166h-4.7A1.712 1.712 0 0 1 .09 20.439L6.595 1.166A1.713 1.713 0 0 1 8.218 0h.034Zm-.66 16.194 6.916 5.137a.428.428 0 0 0 .256.085h.028a.429.429 0 0 0 .405-.566l-3.503-10.38-1.402 3.627-.159.412H5.35l2.243 1.685Zm14.695 5.222h-5.835c.083-.323.07-.662-.037-.977L9.95 1.285h5.832a.428.428 0 0 1 .406.292l6.505 19.273a.43.43 0 0 1-.406.566Z"
            />
        </svg>
    );
}
