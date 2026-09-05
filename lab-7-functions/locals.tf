locals {
  # ---- 1. length() : how many of everything ------------------------------
  env_count = length(var.environments)

  # ---- 2. LIST -> MAP : the single most useful conversion in Terraform ---
  # for_each needs a map (or set); a list gives you index-based addressing,
  # which renumbers everything when an element is removed from the middle.
  # Keying by the environment name makes each resource address stable.
  env_map = { for env in var.environments : env => {
    name          = join("-", [var.project, env])
    instance_type = lookup(var.size_map, env, "t3.micro")
    is_production = contains(var.production_envs, env)
    index         = index(var.environments, env)
  } }

  # ---- 3. split() + trimspace() : cleaning messy input -------------------
  owners_raw   = split(",", var.owner_csv)
  owners       = [for o in local.owners_raw : trimspace(o)]
  owners_tag   = join(";", local.owners)
  owner_domain = distinct([for o in local.owners : element(split("@", o), 1)])

  # ---- 4. upper/title/substr/format : building display strings ----------
  env_labels = { for env in var.environments : env => upper(substr(env, 0, 3)) }

  # ---- 5. MAP -> LIST : the reverse conversion --------------------------
  all_names = [for k, v in local.env_map : v.name]
  sorted    = sort(local.all_names)

  # ---- 6. a computed tag map applied to every instance ------------------
  computed_tags = {
    EnvCount     = tostring(local.env_count)
    AllEnvs      = join(",", var.environments)
    Owners       = local.owners_tag
    OwnerDomains = join(",", local.owner_domain)
    NameFormula  = "join(\"-\", [project, env])"
  }
}
