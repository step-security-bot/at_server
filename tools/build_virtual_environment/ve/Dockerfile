FROM atsigncompany/vebase:latest@sha256:b57a60a3273821fb2ac4cfa514f13b4e2f9a5c8dd169f39fc9adb96a5d62ff3f
USER root

# Secondary binary will be put in place by GitHub Actions
# Context for this Dockerfile is its local directory:
# tools/build_virtual_environment/ve
COPY ./contents /

EXPOSE 64 6379 9001

# Run supervisor configuration file on container startup
CMD ["supervisord", "-n"]