import * as React from "react";
import { ResizablePanels } from "./resizable-panels";
import { cn } from "@/lib/utils";

// SplitLayout: semantic wrapper around ResizablePanels for the common
// left/right split use case.
export function SplitLayout(props: React.ComponentProps<typeof ResizablePanels>) {
  return <ResizablePanels {...props} />;
}
