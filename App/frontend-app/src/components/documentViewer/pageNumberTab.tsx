import React from 'react';
import { Text, Image } from '@fluentui/react-components';
import { Document } from "../../api/apiTypes/embedded";

interface IPageNumberTabProps {
  selectedTab: string;
  selectedPageMetadata: Document | null;
  documentUrl: string | undefined;
}

// Linear, non-backtracking replacement for /^(?:\/\/|[^/]+)*\// (avoids ReDoS).
// Strips an optional "<scheme>://" or leading "//", then everything up to and
// including the next '/'. For absolute/protocol-relative URLs this removes the
// host segment (for example, https://host/path -> path, //host/path -> path),
// and for relative inputs it removes the first path segment (for example,
// foo/bar -> bar), matching the prior regex behavior.
const stripUrlPrefix = (s: string): string => {
  let i = 0;
  // Skip optional "<scheme>://" (e.g. https://, http://, ftp://). Anchored,
  // bounded character class -> no catastrophic backtracking.
  const schemeMatch = /^[a-z][a-z0-9+.-]*:\/\//i.exec(s);
  if (schemeMatch) {
    i = schemeMatch[0].length;
  } else if (s.startsWith("//")) {
    i = 2;
  }
  const slash = s.indexOf("/", i);
  return slash === -1 ? s : s.substring(slash + 1);
};

export const PageNumberTab: React.FC<IPageNumberTabProps> = ({ selectedTab, selectedPageMetadata, documentUrl}) => {
  if (selectedTab !== "Page Number" || !selectedPageMetadata || !documentUrl) {
    return null;
  }

  const imageUrl = window.ENV.STORAGE_URL +
    stripUrlPrefix(selectedPageMetadata.document_url) +
    "/" 

  return (
    <div className="grid w-full grid-cols-4 justify-between gap-4 overflow-y-auto" style={{ width: "200%" }}>
      <div className="col-span-3 grid justify-between gap-4 overflow-y-auto h-[80%] shadow-xl">
        <div className="flex w-full justify-between">
          <Image
            alt="Image of selected page number"
            src={imageUrl}
          />
        </div>
      </div>
      <div className="col-span-1">
        <div className="flex-auto">
          <Text size={300} weight="semibold">
            {selectedPageMetadata.summary}
          </Text>
        </div>
      </div>
    </div>
  );
};