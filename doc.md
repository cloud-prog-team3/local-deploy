# Instance Automation Controller

The **Instance Automation Controller** (`instautoctrl` package) is part of the automation framework developed for the *Cloud Programming* course, Politecnico di Torino, 2025 edition.  
It implements backend logic to manage the lifecycle of instances declared as **Inactive**.

The package includes three controllers:

- [Instance Inactive Termination](#instance-inactive-termination-controller)
- [Instance Termination](#instance-termination-controller)
- [Instance Submission](#instance-submission-controller)

---

## Instance Inactive Termination Controller

This controller monitors instances and automates actions based on their inactivity status and lifespan.  

For each instance, it performs two main checks:

1. **Maximum Lifespan Check**
    - It verifies whether the instance has exceeded its maximum lifespan, as defined by the `DeleteAfter` field in the associated `Template` resource.
    - If exceeded, the instance and its related resources are deleted.

2. **Inactivity Check**
    - It determines if the instance is inactive by comparing its last activity timestamp against the `InactivityTimeout` specified in the `Template`.
    - If the instance is inactive:
        - A series of notification emails are sent to the instance owner.
        - After a configurable number of alerts, **CrownLabs** proceeds to either:
            - Stop the instance (if it is persistent), or
            - Delete the instance (if it is non-persistent).
    - If the instance is not inactive, the check is rescheduled for a future run.

### Detailed Behavior

#### Maximum Lifespan Check
- **Field used**: `Template.spec.DeleteAfter`
- **Action**: Immediate deletion of the instance and related resources if expired.

#### Inactivity Check
- **Field used**: `Template.spec.InactivityTimeout`  
  **Default value**: `60d` (60 days)
- **Actions**:
    - Send inactivity alerts to the instance owner via email. The number of alerts sent is defined in a new annotation `crownlabs.polito.it/number-alerts-sent`
    - After a predefined number of alerts, perform instance stop/delete based on statefulness.
    - Reschedule future checks if the instance remains active.

##### How does the check is performed
TO DO
The controller checks if the Instance has been accessed in the last `InactivityTimeout`. 
checks a query on prometheus 
updates the new `crownlabs.polito.it/last-activity` annotation in the Instance

things for SSH


---

## CRDs Modifications

### `Template` CRD
- A new field `InactivityTimeout` is added:
    - Defines the duration after which an instance is considered inactive.
    - **Default**: `60d`.

    

---

## Deployment with Helm Charts

The `instance-automation-controller` is deployed as part of the **Instance Operator** Helm chart.  
New configurable values are exposed to customize its behavior:

| Parameter                                    | Description                              |
|---------------------------------------------|------------------------------------------|
| `inactiveTerminationStatusCheckTimeout`     | Timeout for checking instance status  TO REMOVE ???   |
| `inactiveTerminationStatusCheckInterval`    | Interval between status checks           |
| `inactiveTerminationMaxNumberOfAlerts`     | Max number of inactivity alerts to send  |
| `smtp` section                              | TO REMOVE ??? |

---

## Instance Termination Controller

This controller focuses on instance termination in **exam scenarios**.

- It verifies if the instance’s public endpoint is still responding (via an HTTP check).
- If the endpoint is unreachable, the controller initiates the termination process for the instance.

---

## Instance Submission Controller

This controller automates **exam submission** workflows.

- It creates a ZIP archive of the instance’s persistent volume (VM disk).
- The archive is uploaded to a configured submission endpoint.

Used during exams to collect student submissions in a reproducible and traceable manner.

---

