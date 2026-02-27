import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-semibold ring-offset-background transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90 shadow-[0_4px_20px_-4px_hsl(173_58%_39%_/_0.15)] hover:shadow-[0_20px_50px_-20px_hsl(210_40%_14%_/_0.2)] hover:-translate-y-0.5",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border-2 border-primary/20 bg-transparent text-foreground hover:bg-primary/5 hover:border-primary/40",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-muted hover:text-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        cta: "bg-gradient-to-r from-[hsl(15,90%,55%)] to-[hsl(25,95%,60%)] text-white shadow-[0_4px_20px_-4px_hsl(173_58%_39%_/_0.15)] hover:shadow-[0_20px_50px_-20px_hsl(210_40%_14%_/_0.2)] hover:-translate-y-0.5 hover:scale-[1.02]",
        hero: "bg-gradient-to-r from-[hsl(173,58%,39%)] via-[hsl(190,70%,45%)] to-[hsl(200,80%,50%)] text-white shadow-[0_0_40px_hsl(173_58%_39%_/_0.25)] hover:shadow-[0_20px_50px_-20px_hsl(210_40%_14%_/_0.2)] hover:-translate-y-1 hover:scale-[1.02] font-bold",
        "hero-outline": "border-2 border-primary/30 bg-card/80 backdrop-blur-sm text-foreground hover:bg-card hover:border-primary/50 hover:shadow-[0_4px_20px_-4px_hsl(173_58%_39%_/_0.15)]",
      },
      size: {
        default: "h-11 px-6 py-2",
        sm: "h-9 rounded-md px-4",
        lg: "h-12 rounded-xl px-8 text-base",
        xl: "h-14 rounded-xl px-10 text-lg",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
