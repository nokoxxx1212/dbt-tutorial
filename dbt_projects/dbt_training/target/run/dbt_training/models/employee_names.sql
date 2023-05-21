
  create view "dbt_training"."public"."employee_names__dbt_tmp" as (
    select
	"employee_id",
	concat("first_name", ' ', "last_name") as full_name
from
	dbt_training.raw.employees
  );