"use client";

import * as React from "react";
import { Settings as SettingsIcon } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { ThemeToggle } from "@/components/shell";
import { Form, SubmitButton, useZodForm } from "@/shared/forms";
import { FormField, TextField, TextareaField } from "@/shared/forms";
import { profileSchema, type ProfileValues } from "@/shared/forms";
import { useToast } from "@/components/feedback";

export default function SettingsPage() {
  const form = useZodForm<ProfileValues>(profileSchema, { name: "Ada Lovelace", bio: "" });
  const { toast } = useToast();
  const [compact, setCompact] = React.useState(false);
  const [alerts, setAlerts] = React.useState(true);

  const onSubmit = async (values: ProfileValues) => {
    await new Promise((r) => setTimeout(r, 600));
    toast({ title: "Saved", description: `${values.name} profile updated.` });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight">
          <SettingsIcon className="h-5 w-5" /> Settings
        </h1>
        <p className="text-sm text-muted-foreground">Manage your profile and preferences.</p>
      </div>

      <Card className="max-w-xl space-y-4 p-5">
        <h3 className="text-sm font-medium">Profile</h3>
        <Form form={form} onSubmit={onSubmit} className="space-y-4">
          <FormField name="name" label="Display name" required>
            <TextField name="name" placeholder="Your name" />
          </FormField>
          <FormField name="bio" label="Bio">
            <TextareaField name="bio" placeholder="A short bio…" />
          </FormField>
          <SubmitButton>Save changes</SubmitButton>
        </Form>
      </Card>

      <Card className="max-w-xl space-y-4 p-5">
        <h3 className="text-sm font-medium">Preferences</h3>
        <div className="flex items-center justify-between">
          <div>
            <Label>Theme</Label>
            <p className="text-xs text-muted-foreground">Toggle light / dark appearance.</p>
          </div>
          <ThemeToggle />
        </div>
        <div className="flex items-center justify-between">
          <div>
            <Label>Compact tables</Label>
            <p className="text-xs text-muted-foreground">Show more rows per page.</p>
          </div>
          <Switch checked={compact} onCheckedChange={setCompact} />
        </div>
        <div className="flex items-center justify-between">
          <div>
            <Label>Price alerts</Label>
            <p className="text-xs text-muted-foreground">Notify me on large moves.</p>
          </div>
          <Switch checked={alerts} onCheckedChange={setAlerts} />
        </div>
      </Card>
    </div>
  );
}
