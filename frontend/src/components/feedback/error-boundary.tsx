"use client";

import * as React from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

interface State {
  error: Error | null;
}

// Catches render errors in a subtree and shows a recoverable fallback.
export class ErrorBoundary extends React.Component<{ children: React.ReactNode; fallback?: React.ReactNode }, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      if (this.props.fallback) return this.props.fallback;
      return (
        <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-destructive/40 bg-destructive/5 px-6 py-10 text-center">
          <AlertTriangle className="h-6 w-6 text-destructive" />
          <p className="text-sm font-medium text-foreground">Something went wrong</p>
          <p className="max-w-sm text-xs text-muted-foreground">{this.state.error.message}</p>
          <Button variant="outline" size="sm" onClick={this.reset}>
            Try again
          </Button>
        </div>
      );
    }
    return this.props.children;
  }
}
