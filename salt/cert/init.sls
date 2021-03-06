include:
  - crypto

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['caasp_fqdn'] ] -%}

{% if "kube-master" in salt['grains.get']('roles', []) %}
  {% do ip_addresses.append("IP: " + pillar['api']['cluster_ip']) %}
  {% for _, interface_addresses in grains['ip4_interfaces'].items() %}
    {% for interface_address in interface_addresses %}
      {% do ip_addresses.append("IP: " + interface_address) %}
    {% endfor %}
  {% endfor %}
  {% for extra_ip in pillar['api']['server']['extra_ips'] %}
    {% do ip_addresses.append("IP: " + extra_ip) %}
  {% endfor %}

  # add some extra names the API server could have
  {% set extra_names = extra_names + ["DNS: api",
                                      "DNS: api." + pillar['internal_infra_domain']] %}
  {% for extra_name in pillar['api']['server']['extra_names'] %}
    {% do extra_names.append("DNS: " + extra_name) %}
  {% endfor %}

  # add the fqdn provided by the user
  # this will be the name used by the kubeconfig generated file
  {% if salt['pillar.get']('api:server:external_fqdn') %}
    {% do extra_names.append("DNS: " + pillar['api']['server']['external_fqdn']) %}
  {% endif %}

  # add some standard extra names from the DNS domain
  {% if salt['pillar.get']('dns:domain') %}
    {% do extra_names.append("DNS: kubernetes.default.svc." + pillar['dns']['domain']) %}
  {% endif %}
{% endif %}

{{ pillar['ssl']['key_file'] }}:
  x509.private_key_managed:
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['crt_file'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['key_file'] }}
    - CN: {{ grains['caasp_fqdn'] }}
    - C: {{ pillar['certificate_information']['subject_properties']['C']|yaml_dquote }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email']|yaml_dquote }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN']|yaml_dquote }}
    - L: {{ pillar['certificate_information']['subject_properties']['L']|yaml_dquote }}
    - O: {{ pillar['certificate_information']['subject_properties']['O']|yaml_dquote }}
    - OU: {{ pillar['certificate_information']['subject_properties']['OU']|yaml_dquote }}
    - SN: {{ pillar['certificate_information']['subject_properties']['SN']|yaml_dquote }}
    - ST: {{ pillar['certificate_information']['subject_properties']['ST']|yaml_dquote }}
    - basicConstraints: "critical CA:false"
    - keyUsage: nonRepudiation, digitalSignature, keyEncipherment
    {% if (ip_addresses|length > 0) or (extra_names|length > 0) %}
    - subjectAltName: "{{ ", ".join(extra_names + ip_addresses) }}"
    {% endif %}
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls:  crypto
      - x509: {{ pillar['ssl']['key_file'] }}
