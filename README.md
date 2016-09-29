# Hadoop Heat Templates

## Run on Chameleon

After sourcing the credentials file downloaded from the Chameleon testbed,
create a heat stack on Chameleon with the following command:

```
heat stack-create heat_hadoop -f hadoop_params.yml -e env_baremetal.yml
```

Update the previously created heat stack with the following command:

```
heat stack-update heat_hadoop -f hadoop_params.yml -e env_baremetal.yml
```

Finally, destroy the heat stack with this command:

```
heat stack-delete heat_hadoop
```

## Run on Roger

After sourcing the credentials file downloaded from the Roger infrastructure,
Create a heat stack on Chameleon with the following command:

```
heat stack-create heat_hadoop -f hadoop_params.yml -e env_roger.yml
```

Update the previously created heat stack with the following command:

```
heat stack-update heat_hadoop -f hadoop_params.yml -e env_roger.yml
```

Finally, destroy the heat stack with this command:

```
heat stack-delete heat_hadoop
```
