# Instructions

1. From the terminal, in the project root directory execute `docker-compose up`
Add `-d` option at the end to run in daemon mode.

    This will start:

    - Grafana
    - Grafana Tempo
    - Prometheus
    - Solace PubSub Standard
    - k6 tracing load generator

2. From the terminal, in the project root directory execute `./applications/semp.sh`

    This will setup necessary Solace capabilities and configurations.

3. Open a web browser and navigate to localhost:8080

4. When prompted authenticate with:

    User Name: admin  
    Password: admin

5. Click on the "default" card on the Message VPN screen.

6. From the left menu, click Telemetry.  

7. From the top tabs, click "Trace Filters"

8. From the list of Trace Filters click "default"

9. From the top tabs, click "Subscriptions"  
The single greater than sign indicates anything published to this broker with guranteed messaging as the quality of service will be recorded in here
greater than is a wild card character for them

10. From the left menu, click "Queues"  
We can see two queues, our basic demo one named letter q and the tracing queue. Both empty. Let's send a message.

11. From the terminal, in the project root directory execute  

    ```bash
    ./sdkperf-jcsmp-8.4.17.5/sdkperf_java.sh -cip=localhost:55554 -cu=default@default -cp=default -ptl=solace/tracing -mt=persistent -mn=1 -ped=0 -cpl=String,show,Picard
    ```

    This will send data into solace.

12. Returning to the browser, click refresh data in lower right
Notice there are zero messages in the telemetry-trace queue because collector took it but message still in "q" queue.

13. Open a new tab in the browser, navigate to localhost:3000

    - From the left menu select Explore
    - Make sure Tempo is selected as the data source.
    - Select Query Type to be search.
    - Select Service name equals Solace
    - Click Run Query
    - Expand the trace below
    - Click the span
    - Open the span attributes in the right pane.
    - See the exact message "show" "Picard"

14. Return to the Solace tab

    - From the left menu, click "try me" tab halfway down
    - In the client password field enter "default" and click connect on the right most button (subscriber)
    - It should say "Connected" underneath.
    - Click bind to an endpoint below on the right.
    - In the text box replace "try-me-queue" with letter "q" for our queue.
    - Click start consume
    - Scroll down, you can see the message sent

15. Go back to queues on left, ignore the warning, click okay

    - see now that the queue "q" is empty

16. Return to the Grafana Tab

    - Click refresh on the right tab, notice that now the send span is there.
    - Open Span attributes for send span and see it is the try me app from the webui.
