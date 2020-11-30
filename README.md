# mainorder install

Installs MainOrder's printer system on raspberry pis.

Before you start: 
- please copy the your SSH key to the device and make sure you can access the mainorder printer repository
- create a new user account and setup the hostname for the machine accordingly.

Now log in to your raspberry pi and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mainorder/install/HEAD/install.sh)"
```

