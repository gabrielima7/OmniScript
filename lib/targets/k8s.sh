#!/usr/bin/env bash
#===============================================================================
# OmniScript - Kubernetes Target Adapter
# Adapter for deploying to Kubernetes clusters via kubectl
#===============================================================================

#-------------------------------------------------------------------------------
# Availability Check
#-------------------------------------------------------------------------------
os_target_check_k8s() {
    if command -v kubectl &> /dev/null; then
        # Check if we can actually connect to a cluster
        if kubectl cluster-info &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Core Functions
#-------------------------------------------------------------------------------
os_k8s_deploy() {
    local service_name="$1"
    local compose_file="${OS_DATA_DIR}/k8s/stacks/${service_name}/deployment.yaml"
    
    # If no K8s manifest exists, check for docker-compose and try to convert or fail
    if [[ ! -f "$compose_file" ]]; then
        local compose_src="${OS_DATA_DIR}/docker/stacks/${service_name}/docker-compose.yml"
        if [[ -f "$compose_src" ]]; then
            os_warn "K8s manifest not found, attempting conversion from Docker Compose..."
            if command -v kompose &> /dev/null; then
                mkdir -p "$(dirname "$compose_file")"
                kompose convert -f "$compose_src" -o "$compose_file"
            else
                os_error "Kompose not found. Please install kompose or provide deployment.yaml"
                return 1
            fi
        else
            os_error "No deployment source found for ${service_name}"
            return 1
        fi
    fi
    
    os_info "Deploying ${service_name} to Kubernetes..."
    kubectl apply -f "$compose_file"
}

os_k8s_remove() {
    local service_name="$1"
    os_info "Removing ${service_name} from Kubernetes..."
    
    # Try to find manifest to delete by file
    local compose_file="${OS_DATA_DIR}/k8s/stacks/${service_name}/deployment.yaml"
    if [[ -f "$compose_file" ]]; then
        kubectl delete -f "$compose_file"
    else
        # Fallback to label selector if we used standard labeling
        kubectl delete all -l app=${service_name}
    fi
}

os_k8s_list() {
    echo -e "${C_BOLD}Kubernetes Deployments:${C_RESET}"
    kubectl get deployments,svc
}

os_k8s_status() {
    local service_name="$1"
    kubectl get all -l app=${service_name}
}

os_k8s_logs() {
    local service_name="$1"
    # Get first pod
    local pod_name
    pod_name=$(kubectl get pods -l app=${service_name} -o jsonpath="{.items[0].metadata.name}")
    
    if [[ -n "$pod_name" ]]; then
        kubectl logs "$pod_name"
    else
        os_error "No pods found for ${service_name}"
    fi
}

os_k8s_exec() {
    local service_name="$1"
    shift
    local cmd="$*"
    
    local pod_name
    pod_name=$(kubectl get pods -l app=${service_name} -o jsonpath="{.items[0].metadata.name}")
    
    if [[ -n "$pod_name" ]]; then
        kubectl exec -it "$pod_name" -- $cmd
    else
        os_error "No pods found for ${service_name}"
    fi
}

os_k8s_start() {
    local service_name="$1"
    os_info "Scaling up ${service_name}..."
    kubectl scale deployment "${service_name}" --replicas=1
}

os_k8s_stop() {
    local service_name="$1"
    os_info "Scaling down ${service_name}..."
    kubectl scale deployment "${service_name}" --replicas=0
}

os_k8s_restart() {
    local service_name="$1"
    os_info "Restarting ${service_name}..."
    kubectl rollout restart deployment "${service_name}"
}

os_k8s_update() {
    local service_name="$1"
    os_info "Updating ${service_name}..."
    os_k8s_deploy "$service_name"
}

os_k8s_backup() {
    os_warn "Backup not yet implemented for Kubernetes target."
}

os_k8s_restore() {
    os_warn "Restore not yet implemented for Kubernetes target."
}
