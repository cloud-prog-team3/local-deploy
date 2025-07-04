# Instance Automation Controller

The **Instance Automation Controller** (`instautoctrl` package) is part of the automation framework developed for the *Cloud Programming* course, Politecnico di Torino, 2025 edition.  
It implements backend logic to manage the lifecycle of instances declared as **Inactive**.

The package includes four controllers:

- [Instance Inactive Termination](#instance-inactive-termination-controller)
- [Instance Termination](#instance-termination-controller)
- [Instance Submission](#instance-submission-controller)
- [Instance Expiration](#instance-expiration-controller)

---

## Instance Inactive Termination Controller

This controller monitors instances and automates actions based on their inactivity status and lifespan. The controller understands if the Instance can be declared as Inactive and starts sending notifications to its tenant to inform them to access their Instance resources, otherwise they will be paused (if persistent) or deleted (if not persistent) after a specific period of time.
- **Field used**: `Template.spec.InactivityTimeout`  
- **Default value**: `never`

### Detailed Behavior
1. The controller retrieve all the active instances.
2. It checks if the Instance has to be monitored or not.
    * On the associated `Namespace` resource a new label called `InstanceInactivityIgnoreNamespace` can be added.
    * If the `Namespace` presents this label, the `Instance` is ignored by the controller, therefore it can stay inactive for a long time and not being stopped/deleted.
3. The controller adds new annotations on the `Instance`:
    * **AlertAnnotationNum**: the number of notifications that has been sent to inform the tenant that the instance has not been used for a certain time and it will be stopped/deleted soon. It ranges from 0 up to `InstanceMaxNumberOfAlerts`.
    * **LastActivityAnnotation**: it represents the last moment the user has accessed to the `Instance` via Frontend (using the Ingress) or via SSH.
    * **LastNotificationTimestampAnnotation**: the timestamp of the last sent notification. It is used to understand if enough time is passed from the previous notification, hence a new one can be sent.
4. The controller checks if the instance is inactive by comparing its last activity timestamp against the `InactivityTimeout` specified in the `Template`.
    - If the instance is inactive (remainingTime <0=):
        - A series of notification emails are sent to the `Instance` owner.
        - After a configurable number of alerts, **CrownLabs** proceeds to either:
            - Stop the `Instance` (if it is persistent), or
            - Delete the `Instance` (if it is non-persistent).
    - If the `Instance` is not inactive (remainingTime >0), the check is rescheduled for a future run.
5. If the `Instance` has been paused and the user restart it, the `AlertAnnotationNum` is reset, the controller evaluate the new `remainingTime` and the entire process repeat itself.
    - This mechanism uses the `LastRunningAnnotation` value to understand if the `Instance` has been restarted after being paused.


### How does the check is performed?
The controller focuses on one point: understand if the `Instance` is being used (and it should not be deleted) or it is not used (and it should be deleted).
An `Instance` can be accessed by the Crownlabs Frontend or via SSH.
The controller uses **Prometheus** to do this check:
* It uses Nginx Metrics to verify the last access to the Frontend
* It uses a custom metric (called **bastion_ssh_connections**) to monitor the SSH accesses.

After this check, the **LastActivityAnnotation** is updated with the most recent timestamp. If the last access is above the max threshold (defined with the `inactivityTimeout` field in the `Template` resource), the `Instance` is declared as **inactive** and (if enabled) email notifications start to be sent at regular interval (**NotificationInterval** parameter).
After the maximum time of notifications, the `Instance` is stopped.

### How does the SSH access is monitored?
Already done in the other PR ??

### Parameters for the reconciler
The **InstanceInactiveTerminationReconciler** adds some new parameters compared to the other controllers:
* **InstanceMaxNumberOfAlerts**: the maximum number of notification that Crownlabs can send before stopping/deleting the Instance. It can be overrided by the `AlertAnnotationNum` annotation that can be in the Template resource.
* **EnableInactivityNotifications**: flag to enable/disable the email notifications.
* **MailClient**: struct containing all the mail configuration.
* **PrometheusURL**: URL of the Prometheus service which is used to scrape metrics about the Instance activity
* **PrometheusNginxAvailability**: Prometheus Query to understand if Nginx Metrics are available in Prometheus
* **PrometheusBastionSSHAvailability**: Prometheus Query to understand if SSH (custom metric) Metrics are available in Prometheus
* **PrometheusNginxData**: Prometheus Query to retrieve metrics about the last (frontend) access to a specific instance.
* **PrometheusBastionSSHData**: Prometheus Query to retrieve metrics about the last (SSH) access to a specific instance.
* **NotificationInterval**: Time interval between two email notifications.
* **StatusCheckRequestTimeout**: The maximum timeout for a request.

### Watch and Predicates
The **InstanceInactiveTerminationReconciler** is set to watch and react to events related to the following resources:
* **Instances**: if an `Instance` has been stopped and the user restart is, the reconciler on that `Instance` must be triggered again to restart the monitoring process. There is a predicate filter (**instanceTriggered**) to let the reconciler reschedule the `Instance`.
* **Templates**: if the `inactivityTimeout` is set or modified in a template, the associated instances must be reconciled to recalculate the remaining time of the associated instances.
* **Namespaces**: if a `Namespace` is set to be monitored (add `InstanceInactivityIgnoreNamespace` label), all the `Instance` of that `Namespace` must be reconciled to evaluate the remaining time of the instance. There is a predicate filter (called **inactivityIgnoreNamespace**) to let the reconciler reschedule the `Instance` if a new `Namespace` has to be checked.


### Labels and Annotations

* **InstanceInactivityIgnoreNamespace**: label added to the `Namespace` to ignore the inactivity termination for the Instances in that `Namespace`. 
* **AlertAnnotationNum**: annotaion to check the number of email notifications already sent to the `Tenant`.
* **LastNotificationTimestampAnnotation**: annotation to check the timestamp of the last email notification sent to the `Tenant`.
* **LastRunningAnnotation**: previous value of the **Running** field of the `Instance`. It is used to check whether the `Instances` have been restarted after being paused.
* **CustomNumberOfAlertsAnnotation**: override the default `InstanceMaxNumberOfAlerts` in the **InstanceInactiveTerminationReconciler** for a specific template.
* **LastRunningAnnotation**:  previous value of the `Running` field of the `Instance`. It is used to check wheather a persistent `Instance` was stopped and now has been started again.

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
## Instance Expiration Controller

This controller is a replacement for the old `delete-stale-instance` python script. It verifies whether the instance has exceeded its maximum lifespan, as defined by the `DeleteAfter` field in the associated `Template` resource. If exceeded, the instance and its related resources are deleted.
- **Field used**: `Template.spec.DeleteAfter`
- **Action**: Immediate deletion of the instance and related resources if expired.


### Detailed Behavior
1. The controller starts and the instances are retrieved. For each `Instance`, the related `Template` resource is retrieved.
    * In the `Template` resource there is the field `DeleteAfter` which defines the maximum lifespan of an `Instance` resource.
    * This value has a default `never` value, which means that the Instance does not have to be terminated.
    * It is possible to set a timeInterval which match the following regex `^(never|[0-9]+[mhd])$`
2. From the `DeleteAfter` value, the remaining lifespan of the `Instance` is evaluated.
3. When this time expires, an email is sent to the owner (tenant) of the `Instance` to inform that the `Instance` will be deleted.
4. After a predefined interval, the `Instance` is actually deleted.
5. Another email is sent to the `Tenant` to inform that the `Instance` reached the maximum lifespan time and has been deleted.

### Parameters for the reconciler
The **InstanceExpirationReconciler** adds some paramters to the controller:
* **StatusCheckRequestTimeout**: The maximum timeout for a request.
* **EnableExpirationNotifications**: Boolean flag to enable the email notifications.
* **MailClient**: mail client configuration
* **NotificationInterval**: It represent how long before the instance is deleted the notification email should be sent to the user.

### Watch and Predicates
The **InstanceExpirationReconciler** is set to watch and react to events related to the following resources:
* **Instances**: if an `Instance` has been stopped and the user restart is, the reconciler on that `Instance` must be triggered again to restart the monitoring process. There is a predicate filter (**instanceTriggered**) to let the reconciler reschedule the `Instance`.
* **Templates**: if the `deleteAfter` value is set or modified in a template, the associated instances must be reconciled to recalculate the remaining time of the associated instances. There is a predicate filter (**deleteAfterChanged**) to let the reconciler reschedule the `Instance` to update the new remaining time.
---

## Crownlabs Email Notifications
TO DO


---
## CRDs Changes

### `Template` CRD
- A new field `InactivityTimeout` is added:
    - Defines the duration after which an instance is considered inactive.
    - **Default**: `never`
- A new field `DeleteAfter` is added:
    - Defines the maximum duration after which an instance has to be deleted.
    - **Default**: `never`

---